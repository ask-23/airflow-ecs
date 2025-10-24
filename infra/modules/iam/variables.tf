variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "dags_bucket" {
  description = "S3 bucket for DAGs"
  type        = string
}

variable "logs_bucket" {
  description = "S3 bucket for logs"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for secrets"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
