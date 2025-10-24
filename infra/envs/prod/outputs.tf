output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.endpoint
  sensitive   = true
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs.service_name
}

output "dags_bucket" {
  description = "S3 bucket for DAGs"
  value       = module.s3.dags_bucket_name
}

output "logs_bucket" {
  description = "S3 bucket for logs"
  value       = module.s3.logs_bucket_name
}

output "s3_endpoint_id" {
  description = "S3 VPC endpoint ID"
  value       = module.vpc.s3_endpoint_id
}

output "monitoring_dashboard" {
  description = "CloudWatch dashboard name"
  value       = module.monitoring.dashboard_name
}
