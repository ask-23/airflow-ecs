output "ecs_tasks_security_group_id" {
  description = "ECS tasks security group ID"
  value       = aws_security_group.ecs_tasks.id
}

output "web_service_name" {
  description = "Web service name"
  value       = aws_ecs_service.web.name
}

output "scheduler_service_name" {
  description = "Scheduler service name"
  value       = aws_ecs_service.scheduler.name
}

output "worker_service_name" {
  description = "Worker service name"
  value       = aws_ecs_service.worker.name
}

output "web_task_definition_arn" {
  description = "Web task definition ARN"
  value       = aws_ecs_task_definition.web.arn
}

output "scheduler_task_definition_arn" {
  description = "Scheduler task definition ARN"
  value       = aws_ecs_task_definition.scheduler.arn
}

output "worker_task_definition_arn" {
  description = "Worker task definition ARN"
  value       = aws_ecs_task_definition.worker.arn
}

output "web_log_group" {
  description = "Web CloudWatch log group name"
  value       = aws_cloudwatch_log_group.web.name
}

output "scheduler_log_group" {
  description = "Scheduler CloudWatch log group name"
  value       = aws_cloudwatch_log_group.scheduler.name
}

output "worker_log_group" {
  description = "Worker CloudWatch log group name"
  value       = aws_cloudwatch_log_group.worker.name
}
