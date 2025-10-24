variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
  default     = "381492153064"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for deployment"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# RDS Configuration
variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 100
}

variable "rds_multi_az" {
  description = "Enable RDS multi-AZ"
  type        = bool
  default     = true
}

variable "rds_backup_retention" {
  description = "RDS backup retention in days"
  type        = number
  default     = 30
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "airflow"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "airflow"
  sensitive   = true
}

# ECS Configuration
variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
  default     = "airflow-prod"
}

variable "ecs_task_cpu" {
  description = "ECS task CPU units"
  type        = number
  default     = 2048
}

variable "ecs_task_memory" {
  description = "ECS task memory in MB"
  type        = number
  default     = 4096
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 3
}

variable "airflow_image" {
  description = "Airflow Docker image"
  type        = string
  default     = "apache/airflow:2.8.0"
}

# Monitoring
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 90
}

variable "alarm_email" {
  description = "Email for CloudWatch alarms"
  type        = string
}
