# --- Identity -----------------------------------------------------------------

variable "name" {
  description = "Name for the service and everything it owns (ECR repo, log group, IAM, task family), e.g. \"ecs-3-tier-app-backend\""
  type        = string
}

variable "container_name" {
  description = "Container name inside the task definition"
  type        = string
}

# --- Container ----------------------------------------------------------------

variable "image" {
  description = "Container image URI for the initial task definition"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
}

variable "command" {
  description = "Override the image's CMD (null = use the image default)"
  type        = list(string)
  default     = null
}

variable "cpu" {
  description = "Task CPU units (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Task memory in MiB"
  type        = number
  default     = 512
}

variable "environment" {
  description = "Plain environment variables (name => value)"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secrets injected as environment variables (name => Secrets Manager ARN)"
  type        = map(string)
  default     = {}
}

variable "execution_role_name" {
  description = "Name of the existing ECS task execution role"
  type        = string
  default     = "ecsTaskExecutionRole"
}

variable "log_retention_days" {
  description = "CloudWatch log retention"
  type        = number
  default     = 7
}

# --- Placement ----------------------------------------------------------------

variable "cluster_id" {
  description = "ECS cluster ID (ARN)"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name (used for the autoscaling resource ID)"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the tasks"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups for the tasks"
  type        = list(string)
}

# --- Connectivity -------------------------------------------------------------

variable "service_connect_namespace_arn" {
  description = "Service Connect namespace the service joins"
  type        = string
}

variable "service_connect" {
  description = "Publish this service in the namespace so others can call http://<dns_name>:<container_port>. null = client only."
  type = object({
    dns_name = string
  })
  default = null
}

variable "load_balancer" {
  description = "Register tasks in an ALB target group. null = not behind a load balancer."
  type = object({
    target_group_arn = string
    resource_label   = string # "<alb arn_suffix>/<tg arn_suffix>", for request-count autoscaling
  })
  default = null
}

# --- Scaling ------------------------------------------------------------------

variable "desired_count" {
  description = "Initial number of tasks (autoscaling takes over after the first apply)"
  type        = number
  default     = 1
}

variable "autoscaling_min" {
  description = "Minimum number of tasks"
  type        = number
  default     = 1
}

variable "autoscaling_max" {
  description = "Maximum number of tasks"
  type        = number
  default     = 2
}

variable "cpu_target" {
  description = "Target average CPU utilisation (%)"
  type        = number
  default     = 70
}

variable "memory_target" {
  description = "Target average memory utilisation (%)"
  type        = number
  default     = 70
}

variable "requests_per_target" {
  description = "Target ALB requests per task (only used with load_balancer)"
  type        = number
  default     = 1000
}
