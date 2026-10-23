# PostgreSQL on RDS plus the Secrets Manager secret holding the full
# connection string (DB_LINK) that the application reads at startup.

locals {
  identifier = "${var.name}-db"
  db_link    = "postgresql://${var.username}:${random_password.master.result}@${aws_db_instance.this.address}:${aws_db_instance.this.port}/${var.db_name}"
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-rds-subnet-group"
  subnet_ids = var.subnet_ids
}

# Generated and owned by Terraform (not AWS-managed) so it can be embedded
# directly in the DB_LINK secret below.
resource "random_password" "master" {
  length  = 32
  special = false
}

resource "aws_db_instance" "this" {
  identifier             = local.identifier
  engine                 = "postgres"
  engine_version         = var.engine_version
  instance_class         = var.instance_class
  port                   = var.db_port
  allocated_storage      = var.allocated_storage
  storage_encrypted      = true
  db_name                = var.db_name
  username               = var.username
  password               = random_password.master.result
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.security_group_ids
  multi_az               = var.multi_az
  publicly_accessible    = false
  skip_final_snapshot    = var.skip_final_snapshot
}

resource "aws_secretsmanager_secret" "db_link" {
  name                    = local.identifier
  recovery_window_in_days = var.secret_recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "db_link" {
  secret_id     = aws_secretsmanager_secret.db_link.id
  secret_string = local.db_link
}
