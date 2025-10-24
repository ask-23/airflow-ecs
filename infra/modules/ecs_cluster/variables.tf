variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "enable_fargate_spot" {
  description = "Enable Fargate Spot for workers"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
