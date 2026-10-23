locals {
  # Build a map of AZ => CIDR, so each subnet is keyed by its AZ (e.g. "eu-central-1a")
  public_subnets   = zipmap(var.availability_zones, var.public_subnet_cidrs)
  private_subnets  = zipmap(var.availability_zones, var.private_subnet_cidrs)
  database_subnets = length(var.database_subnet_cidrs) > 0 ? zipmap(var.availability_zones, var.database_subnet_cidrs) : {}
  # AZs that get a NAT gateway: ---difficult : HARD
  #   NAT disabled -> []
  #   single NAT   -> ["eu-central-1a"]            (first AZ only)
  #   NAT per AZ   -> ["eu-central-1a", "eu-central-1b", ...]
  nat_azs = (
    !var.enable_nat_gateway ? [] :
    var.need_single_nat_gateway ? [var.availability_zones[0]] :
    var.availability_zones
  )
}

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.name
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name}-igw"
  }
}

# ---------------------------------------------------------------------------
# Subnets
# ---------------------------------------------------------------------------

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name = "${var.name}-public-${each.key}"
  }
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name = "${var.name}-private-${each.key}"
  }
}

resource "aws_subnet" "database" {
  for_each = local.database_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name = "${var.name}-database-${each.key}"
  }
}

# ---------------------------------------------------------------------------
# Public routing
# ---------------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name}-public-rt"
  }
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# NAT gateway (optional)
# ---------------------------------------------------------------------------

resource "aws_eip" "nat" {
  for_each = toset(local.nat_azs)

  domain = "vpc"

  tags = {
    Name = "${var.name}-nat-eip-${each.key}"
  }
}

resource "aws_nat_gateway" "nat" {
  for_each = toset(local.nat_azs)

  # Same key (the AZ) picks the matching EIP and public subnet
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = {
    Name = "${var.name}-nat-${each.key}"
  }

  # The NAT gateway needs the IGW to exist before it can route traffic
  depends_on = [aws_internet_gateway.igw]
}

# ---------------------------------------------------------------------------
# Private routing
# ---------------------------------------------------------------------------

# One private route table per AZ, so each AZ can point at its own NAT gateway
resource "aws_route_table" "private" {
  for_each = local.private_subnets

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name}-private-rt-${each.key}"
  }
}

resource "aws_route" "private_default" {
  for_each = var.enable_nat_gateway ? local.private_subnets : {}

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"

  # NAT per AZ  -> use the NAT in the same AZ
  # Single NAT  -> every AZ uses the one NAT in the first AZ
  nat_gateway_id = aws_nat_gateway.nat[
    contains(local.nat_azs, each.key) ? each.key : local.nat_azs[0]
  ].id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

#---------------------------------------------------------------------
# Database routing - isolated subnets with no internet access, so no routes are created
#--------------------------------------------------------------------
# Isolated: only the implicit local VPC route, no 0.0.0.0/0

resource "aws_route_table" "database" {
  count  = length(local.database_subnets) > 0 ? 1 : 0
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name}-database-rt"
  }
}

resource "aws_route_table_association" "database" {
  for_each = aws_subnet.database

  subnet_id      = each.value.id
  route_table_id = aws_route_table.database[0].id
}