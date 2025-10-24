variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
  default     = "381492153064"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
}

variable "dags_bucket" {
  description = "S3 bucket for DAGs"
  type        = string
  default     = "pathwai-airflow3-dags"
}

variable "logs_bucket" {
  description = "S3 bucket for logs"
  type        = string
  default     = "pathwai-airflow3-logs"
}

variable "alb_certificate_arn" {
  description = "ACM certificate ARN"
  type        = string
}

variable "db_master_username" {
  description = "RDS master username"
  type        = string
  sensitive   = true
}

variable "db_master_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}
