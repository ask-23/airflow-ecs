output "file_system_id" {
  description = "EFS file system ID"
  value       = aws_efs_file_system.main.id
}

output "file_system_arn" {
  description = "EFS file system ARN"
  value       = aws_efs_file_system.main.arn
}

output "dags_access_point_id" {
  description = "DAGs access point ID"
  value       = aws_efs_access_point.dags.id
}

output "plugins_access_point_id" {
  description = "Plugins access point ID"
  value       = aws_efs_access_point.plugins.id
}

output "security_group_id" {
  description = "EFS security group ID"
  value       = aws_security_group.efs.id
}

output "kms_key_id" {
  description = "KMS key ID"
  value       = aws_kms_key.efs.id
}
