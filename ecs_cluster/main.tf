# Shared ECS infrastructure used by every service: the cluster and the
# Service Connect namespace that lets services find each other privately
# by name (e.g. the frontend calls http://backend:8000).

resource "aws_service_discovery_http_namespace" "this" {
  name        = var.name
  description = "Service Connect namespace for ${var.name}"
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name}-cluster"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  # Services in this cluster join the namespace by default
  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.this.arn
  }
}
