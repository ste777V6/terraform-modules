output "cluster_id" {
  description = "ECS cluster ID (ARN)"
  value       = aws_ecs_cluster.this.id
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.this.name
}

output "service_connect_namespace_arn" {
  description = "ARN of the Service Connect (Cloud Map HTTP) namespace"
  value       = aws_service_discovery_http_namespace.this.arn
}
