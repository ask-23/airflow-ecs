output "db_instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.airflow.id
}

output "db_instance_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.airflow.endpoint
}

output "db_instance_address" {
  description = "RDS instance address"
  value       = aws_db_instance.airflow.address
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.airflow.db_name
}

output "security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

output "kms_key_id" {
  description = "KMS key ID"
  value       = aws_kms_key.rds.id
}
