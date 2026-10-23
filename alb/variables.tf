variable "name" {
  description = "Name prefix for the ALB and target groups. AWS limits these names to 32 characters, so keep this short."
  type        = string

  validation {
    # Longest generated name is "<name>-tg-green" (9 extra characters)
    condition     = length(var.name) <= 23
    error_message = "name must be 23 characters or fewer (ALB/target group names are limited to 32)."
  }
}

variable "vpc_id" {
  description = "VPC for the target groups"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets for the ALB (at least two AZs)"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group attached to the ALB"
  type        = string
}

variable "certificate_domain" {
  description = "FQDN the TLS certificate is issued for, e.g. app.example.com"
  type        = string
}

variable "certificate_validation_timeout" {
  description = "How long to wait for the DNS validation CNAME to be created and the certificate issued"
  type        = string
  default     = "45m"
}

variable "log_bucket_name" {
  description = "Globally unique S3 bucket name for ALB access logs"
  type        = string
}

variable "log_prefix" {
  description = "Prefix for log objects inside the bucket"
  type        = string
  default     = "alb"
}

variable "app_port" {
  description = "Port the target groups send traffic to"
  type        = number
  default     = 5000
}

variable "health_check_path" {
  description = "HTTP path used for target health checks"
  type        = string
  default     = "/"
}

variable "ssl_policy" {
  description = "TLS policy for the HTTPS listener"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "enable_deletion_protection" {
  description = "Prevent the ALB from being deleted (recommended for production)"
  type        = bool
  default     = false
}
