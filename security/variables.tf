variable "name" {
  description = "Name prefix for the security groups"
  type        = string
}

variable "vpc_id" {
  description = "VPC to create the security groups in"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR, used to keep tier-to-tier traffic inside the VPC"
  type        = string
}

variable "frontend_port" {
  description = "Port the frontend container listens on"
  type        = number
  default     = 80
}

variable "backend_port" {
  description = "Port the backend container listens on"
  type        = number
  default     = 8000
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}
