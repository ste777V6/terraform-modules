variable "name" {
  description = "Name prefix for the DB instance, subnet group and secret"
  type        = string
}


variable "subnet_ids" {
  description = "Subnet IDs for the DB subnet group (at least two AZs)"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups attached to the DB instance"
  type        = list(string)
}

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Storage in GiB"
  type        = number
  default     = 20
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "Name of the initial database"
  type        = string
  default     = "mydb"
}

variable "username" {
  description = "Master username"
  type        = string
  default     = "myuser"
}

variable "multi_az" {
  description = "Run a standby in a second AZ (roughly doubles cost)"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot on destroy. Set to false for production."
  type        = bool
  default     = true
}

variable "secret_recovery_window_in_days" {
  description = "Days before a deleted secret is permanently removed. 0 = delete immediately (convenient for dev)."
  type        = number
  default     = 0
}
