output "secret_arn" {
  description = "ARN of the Secrets Manager secret containing the DB_LINK connection string"
  value       = aws_secretsmanager_secret.db_link.arn

  depends_on = [
    aws_secretsmanager_secret_version.db_link
  ]
}

output "address" {
  description = "Hostname of the DB instance"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Port of the DB instance"
  value       = aws_db_instance.this.port
}

output "identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.this.identifier
}
