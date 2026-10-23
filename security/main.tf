# Security groups for the three tiers, chained so each tier only accepts
# traffic from the one in front of it:
#
#   internet -> ALB -> frontend (ECS) -> backend (ECS) -> RDS
#
# They reference each other, so they live together in one module.

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from the internet (redirected to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from the internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "To frontend tasks"
    from_port   = var.frontend_port
    to_port     = var.frontend_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "${var.name}-alb-sg"
  }
}

resource "aws_security_group" "frontend" {
  name        = "${var.name}-frontend-sg"
  description = "Security group for frontend ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Frontend port from the ALB only"
    from_port       = var.frontend_port
    to_port         = var.frontend_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "To backend tasks (Service Connect)"
    from_port   = var.backend_port
    to_port     = var.backend_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "HTTPS out (ECR, CloudWatch Logs, ECS Exec via NAT)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-frontend-sg"
  }
}

resource "aws_security_group" "backend" {
  name        = "${var.name}-backend-sg"
  description = "Security group for backend ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Backend port from frontend tasks only"
    from_port       = var.backend_port
    to_port         = var.backend_port
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  egress {
    description = "To the database inside the VPC"
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "HTTPS out (ECR, Secrets Manager, CloudWatch Logs, ECS Exec via NAT)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-backend-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.name}-rds-sg"
  description = "Security group for RDS instance"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Database port from backend tasks only"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  tags = {
    Name = "${var.name}-rds-sg"
  }
}
