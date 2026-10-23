variable "name" {
  description = "Name for the cluster and the Service Connect namespace"
  type        = string
}

variable "enable_container_insights" {
  description = "Enable Container Insights (extra cost, recommended for production)"
  type        = bool
  default     = false
}
