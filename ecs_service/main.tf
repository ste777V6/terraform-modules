# One ECS Fargate service and everything it owns: image repository, log
# group, IAM, task definition, service and autoscaling.
#
# Used once per tier. Optional features:
#   - load_balancer   : register tasks in an ALB target group (frontend)
#   - service_connect : publish the service in the namespace under a DNS
#                       name so others can call it privately (backend)
# Every service joins the Service Connect namespace as a client, so it can
# call any published service by name.

data "aws_region" "current" {}

locals {
  log_group_name = "/ecs/${var.name}"

  # Service Connect refers to the port mapping by this name
  port_name = "http"

  container_definition = merge(
    {
      name      = var.container_name
      image     = var.image
      essential = true

      portMappings = [{
        name          = local.port_name
        containerPort = var.container_port
        hostPort      = var.container_port
        protocol      = "tcp"
        appProtocol   = "http"
      }]

      environment = [for k, v in var.environment : { name = k, value = v }]
      secrets     = [for k, v in var.secrets : { name = k, valueFrom = v }]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = "app"
        }
      }
    },
    # Only override the image's CMD when a command is given
    { for k, v in { command = var.command } : k => v if v != null }
  )
}

# ---------------------------------------------------------------------------
# IAM
# ---------------------------------------------------------------------------

# Execution role: used by the ECS agent to pull the image, write logs and
# read secrets. It already exists in the account, so we look it up.
data "aws_iam_role" "execution" {
  name = var.execution_role_name
}

resource "aws_iam_policy" "secrets_read" {
  count = length(var.secrets) > 0 ? 1 : 0

  name        = "${var.name}-secrets-read"
  description = "Allow the ECS execution role to read the ${var.name} secrets"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = values(var.secrets)
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execution_secrets" {
  count = length(var.secrets) > 0 ? 1 : 0

  role       = data.aws_iam_role.execution.name
  policy_arn = aws_iam_policy.secrets_read[0].arn
}

# Task role: permissions for the application itself (here: ECS Exec via SSM).
resource "aws_iam_role" "task" {
  name = "${var.name}-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "exec" {
  name        = "${var.name}-ecs-exec-ssm"
  description = "Allow ECS Exec (SSM) sessions into ${var.name} tasks"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_exec" {
  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.exec.arn
}

# ---------------------------------------------------------------------------
# Registry and logs
# ---------------------------------------------------------------------------

resource "aws_ecr_repository" "this" {
  name                 = "${var.name}-ecr"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
}

# ---------------------------------------------------------------------------
# Task definition and service
# ---------------------------------------------------------------------------

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = data.aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([local.container_definition])

  # The pipeline registers new revisions with new images; don't let
  # Terraform roll the container definition back.
  lifecycle {
    ignore_changes = [container_definitions]
  }
}

resource "aws_ecs_service" "this" {
  name                   = "${var.name}-service"
  cluster                = var.cluster_id
  task_definition        = aws_ecs_task_definition.this.arn
  desired_count          = var.desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = var.load_balancer == null ? [] : [var.load_balancer]

    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = var.container_name
      container_port   = var.container_port
    }
  }

  # Joins the namespace as a client (can call published services by name).
  # With var.service_connect set, it is also published under a DNS name.
  service_connect_configuration {
    enabled   = true
    namespace = var.service_connect_namespace_arn

    dynamic "service" {
      for_each = var.service_connect == null ? [] : [var.service_connect]

      content {
        port_name      = local.port_name
        discovery_name = service.value.dns_name

        client_alias {
          dns_name = service.value.dns_name
          port     = var.container_port
        }
      }
    }

    # Logs from the Service Connect (Envoy) sidecar, useful for debugging
    log_configuration {
      log_driver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.this.name
        "awslogs-region"        = data.aws_region.current.region
        "awslogs-stream-prefix" = "service-connect"
      }
    }
  }

  # Autoscaling owns the running task count after the first apply
  lifecycle {
    ignore_changes = [desired_count]
  }

  # Execution role must be able to read secrets before tasks start
  depends_on = [aws_iam_role_policy_attachment.execution_secrets]
}

# ---------------------------------------------------------------------------
# Autoscaling
# ---------------------------------------------------------------------------

resource "aws_appautoscaling_target" "this" {
  min_capacity       = var.autoscaling_min
  max_capacity       = var.autoscaling_max
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  service_namespace  = aws_appautoscaling_target.this.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.cpu_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "memory" {
  name               = "${var.name}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  service_namespace  = aws_appautoscaling_target.this.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.memory_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Only for services behind the ALB
resource "aws_appautoscaling_policy" "request_count" {
  count = var.load_balancer == null ? 0 : 1

  name               = "${var.name}-request-count-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  service_namespace  = aws_appautoscaling_target.this.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = var.load_balancer.resource_label
    }
    target_value       = var.requests_per_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
