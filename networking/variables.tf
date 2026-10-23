variable "name" {
  description = "Name prefix used for all networking resources (e.g. \"main\")"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block, e.g. 10.0.0.0/16."
  }
}

variable "availability_zones" {
  description = "AZs to spread subnets across. Order matters: index N pairs with index N of the subnet CIDR lists."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "Provide at least two availability zones."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per availability zone"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per availability zone"
  type        = list(string)
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for isolated database subnets, one per AZ (empty = none)"
  type        = list(string)
}


variable "enable_nat_gateway" {
  description = "Create a single NAT gateway so private subnets can reach the internet"
  type        = bool
}

variable "need_single_nat_gateway" {
  description = "Create a single NAT gateway so private subnets can reach the internet"
  type        = bool
}
