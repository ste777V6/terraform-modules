output "alb_sg_id" {
  description = "Security group ID for the ALB"
  value       = aws_security_group.alb.id
}

output "frontend_sg_id" {
  description = "Security group ID for the frontend ECS tasks"
  value       = aws_security_group.frontend.id
}

output "backend_sg_id" {
  description = "Security group ID for the backend ECS tasks"
  value       = aws_security_group.backend.id
}

output "rds_sg_id" {
  description = "Security group ID for the RDS instance"
  value       = aws_security_group.rds.id
}
