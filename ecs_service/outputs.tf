output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.this.name
}

output "task_definition_family" {
  description = "Task definition family"
  value       = aws_ecs_task_definition.this.family
}

output "container_name" {
  description = "Container name in the task definition"
  value       = var.container_name
}

output "ecr_repository_url" {
  description = "ECR repository URL to push images to"
  value       = aws_ecr_repository.this.repository_url
}

output "log_group_name" {
  description = "CloudWatch log group for the containers"
  value       = aws_cloudwatch_log_group.this.name
}

output "task_role_arn" {
  description = "ARN of the task role"
  value       = aws_iam_role.task.arn
}

# depends_on: Service Connect clients only learn about services that exist
# when their tasks start. Anything consuming this URL (the frontend) is
# therefore created after this service is published in the namespace.
output "service_connect_url" {
  description = "URL other services use to reach this one (null when not published)"
  value       = var.service_connect == null ? null : "http://${var.service_connect.dns_name}:${var.container_port}"
  depends_on  = [aws_ecs_service.this]
}
