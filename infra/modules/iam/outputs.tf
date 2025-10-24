output "ecs_task_execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "airflow_web_role_arn" {
  description = "Airflow web task role ARN"
  value       = aws_iam_role.airflow_web.arn
}

output "airflow_scheduler_role_arn" {
  description = "Airflow scheduler task role ARN"
  value       = aws_iam_role.airflow_scheduler.arn
}

output "airflow_worker_role_arn" {
  description = "Airflow worker task role ARN"
  value       = aws_iam_role.airflow_worker.arn
}

output "s3_sync_role_arn" {
  description = "S3 sync sidecar task role ARN"
  value       = aws_iam_role.s3_sync.arn
}
