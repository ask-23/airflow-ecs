variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "ecs_cluster_id" {
  description = "ECS cluster ID"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "alb_security_group_id" {
  description = "ALB security group ID"
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN"
  type        = string
}

variable "execution_role_arn" {
  description = "ECS task execution role ARN"
  type        = string
}

variable "web_task_role_arn" {
  description = "Airflow web task role ARN"
  type        = string
}

variable "scheduler_task_role_arn" {
  description = "Airflow scheduler task role ARN"
  type        = string
}

variable "worker_task_role_arn" {
  description = "Airflow worker task role ARN"
  type        = string
}

variable "efs_file_system_id" {
  description = "EFS file system ID"
  type        = string
}

variable "efs_dags_access_point_id" {
  description = "EFS DAGs access point ID"
  type        = string
}

variable "efs_plugins_access_point_id" {
  description = "EFS plugins access point ID"
  type        = string
}

variable "db_connection_string" {
  description = "Database connection string"
  type        = string
  sensitive   = true
}

variable "redis_connection_string" {
  description = "Redis connection string"
  type        = string
  sensitive   = true
}

variable "dags_bucket" {
  description = "S3 bucket for DAGs"
  type        = string
}

variable "logs_bucket" {
  description = "S3 bucket for logs"
  type        = string
}

variable "web_image" {
  description = "Airflow web Docker image"
  type        = string
}

variable "scheduler_image" {
  description = "Airflow scheduler Docker image"
  type        = string
}

variable "worker_image" {
  description = "Airflow worker Docker image"
  type        = string
}

variable "sidecar_image" {
  description = "S3 sync sidecar Docker image"
  type        = string
}

variable "web_cpu" {
  description = "Web CPU units"
  type        = number
  default     = 512
}

variable "web_memory" {
  description = "Web memory in MB"
  type        = number
  default     = 1024
}

variable "web_desired_count" {
  description = "Web desired task count"
  type        = number
  default     = 2
}

variable "scheduler_cpu" {
  description = "Scheduler CPU units"
  type        = number
  default     = 1024
}

variable "scheduler_memory" {
  description = "Scheduler memory in MB"
  type        = number
  default     = 2048
}

variable "worker_cpu" {
  description = "Worker CPU units"
  type        = number
  default     = 1024
}

variable "worker_memory" {
  description = "Worker memory in MB"
  type        = number
  default     = 2048
}

variable "worker_desired_count" {
  description = "Worker initial desired count"
  type        = number
  default     = 2
}

variable "worker_min_count" {
  description = "Worker minimum count"
  type        = number
  default     = 0
}

variable "worker_max_count" {
  description = "Worker maximum count"
  type        = number
  default     = 10
}

variable "worker_concurrency" {
  description = "Celery worker concurrency"
  type        = number
  default     = 4
}

variable "enable_fargate_spot" {
  description = "Enable Fargate Spot for workers"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
