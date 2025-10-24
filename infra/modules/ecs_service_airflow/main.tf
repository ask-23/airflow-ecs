# ECS Service Module for Airflow (Web, Scheduler, Workers)

terraform {
  required_version = ">= 1.12"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name_prefix = "${var.name_prefix}-ecs-tasks-"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "From ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  # Allow tasks to communicate with each other
  ingress {
    description = "From other tasks"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "To VPC endpoints and services"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-ecs-tasks-sg" })
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "web" {
  name              = "/aws/ecs/${var.name_prefix}/web"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, { Name = "${var.name_prefix}-web-logs" })
}

resource "aws_cloudwatch_log_group" "scheduler" {
  name              = "/aws/ecs/${var.name_prefix}/scheduler"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, { Name = "${var.name_prefix}-scheduler-logs" })
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/aws/ecs/${var.name_prefix}/worker"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, { Name = "${var.name_prefix}-worker-logs" })
}

resource "aws_cloudwatch_log_group" "sidecar" {
  name              = "/aws/ecs/${var.name_prefix}/sidecar"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, { Name = "${var.name_prefix}-sidecar-logs" })
}

# Airflow Web Task Definition
resource "aws_ecs_task_definition" "web" {
  family                   = "${var.name_prefix}-web"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.web_cpu
  memory                   = var.web_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.web_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "airflow-web"
      image     = var.web_image
      essential = true
      
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "AIRFLOW__CORE__EXECUTOR", value = "CeleryExecutor" },
        { name = "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN", value = var.db_connection_string },
        { name = "AIRFLOW__CELERY__BROKER_URL", value = var.redis_connection_string },
        { name = "AIRFLOW__CELERY__RESULT_BACKEND", value = var.db_connection_string },
        { name = "AIRFLOW__CORE__LOAD_EXAMPLES", value = "False" },
        { name = "AIRFLOW__WEBSERVER__EXPOSE_CONFIG", value = "False" }
      ]

      mountPoints = [
        {
          sourceVolume  = "efs-dags"
          containerPath = "/opt/airflow/dags"
          readOnly      = true
        },
        {
          sourceVolume  = "efs-plugins"
          containerPath = "/opt/airflow/plugins"
          readOnly      = true
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 5
        startPeriod = 120
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.web.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  volume {
    name = "efs-dags"
    efs_volume_configuration {
      file_system_id     = var.efs_file_system_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = var.efs_dags_access_point_id
      }
    }
  }

  volume {
    name = "efs-plugins"
    efs_volume_configuration {
      file_system_id     = var.efs_file_system_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = var.efs_plugins_access_point_id
      }
    }
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-web-task" })
}

# Airflow Web Service
resource "aws_ecs_service" "web" {
  name            = "${var.name_prefix}-web"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = var.web_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "airflow-web"
    container_port   = 8080
  }

  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-web-service" })
}

# Airflow Scheduler Task Definition
resource "aws_ecs_task_definition" "scheduler" {
  family                   = "${var.name_prefix}-scheduler"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.scheduler_cpu
  memory                   = var.scheduler_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.scheduler_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "airflow-scheduler"
      image     = var.scheduler_image
      essential = true

      environment = [
        { name = "AIRFLOW__CORE__EXECUTOR", value = "CeleryExecutor" },
        { name = "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN", value = var.db_connection_string },
        { name = "AIRFLOW__CELERY__BROKER_URL", value = var.redis_connection_string },
        { name = "AIRFLOW__CELERY__RESULT_BACKEND", value = var.db_connection_string },
        { name = "AIRFLOW__CORE__LOAD_EXAMPLES", value = "False" },
        { name = "AIRFLOW__CORE__REMOTE_LOGGING", value = "True" },
        { name = "AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER", value = "s3://${var.logs_bucket}/${var.environment}/logs" }
      ]

      mountPoints = [
        {
          sourceVolume  = "efs-dags"
          containerPath = "/opt/airflow/dags"
          readOnly      = false
        },
        {
          sourceVolume  = "efs-plugins"
          containerPath = "/opt/airflow/plugins"
          readOnly      = false
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "airflow jobs check --job-type scheduler || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 5
        startPeriod = 120
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.scheduler.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    },
    {
      name      = "s3-sync-sidecar"
      image     = var.sidecar_image
      essential = false

      environment = [
        { name = "DAGS_BUCKET", value = var.dags_bucket },
        { name = "ENV", value = var.environment }
      ]

      mountPoints = [
        {
          sourceVolume  = "efs-dags"
          containerPath = "/opt/airflow/dags"
          readOnly      = false
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.sidecar.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  volume {
    name = "efs-dags"
    efs_volume_configuration {
      file_system_id     = var.efs_file_system_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = var.efs_dags_access_point_id
      }
    }
  }

  volume {
    name = "efs-plugins"
    efs_volume_configuration {
      file_system_id     = var.efs_file_system_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = var.efs_plugins_access_point_id
      }
    }
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-scheduler-task" })
}

# Airflow Scheduler Service
resource "aws_ecs_service" "scheduler" {
  name            = "${var.name_prefix}-scheduler"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.scheduler.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-scheduler-service" })
}

# Airflow Worker Task Definition
resource "aws_ecs_task_definition" "worker" {
  family                   = "${var.name_prefix}-worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.worker_cpu
  memory                   = var.worker_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.worker_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "airflow-worker"
      image     = var.worker_image
      essential = true

      environment = [
        { name = "AIRFLOW__CORE__EXECUTOR", value = "CeleryExecutor" },
        { name = "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN", value = var.db_connection_string },
        { name = "AIRFLOW__CELERY__BROKER_URL", value = var.redis_connection_string },
        { name = "AIRFLOW__CELERY__RESULT_BACKEND", value = var.db_connection_string },
        { name = "AIRFLOW__CORE__LOAD_EXAMPLES", value = "False" },
        { name = "AIRFLOW__CORE__REMOTE_LOGGING", value = "True" },
        { name = "AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER", value = "s3://${var.logs_bucket}/${var.environment}/logs" },
        { name = "AIRFLOW__CELERY__WORKER_CONCURRENCY", value = tostring(var.worker_concurrency) }
      ]

      mountPoints = [
        {
          sourceVolume  = "efs-dags"
          containerPath = "/opt/airflow/dags"
          readOnly      = true
        },
        {
          sourceVolume  = "efs-plugins"
          containerPath = "/opt/airflow/plugins"
          readOnly      = true
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "airflow jobs check --job-type worker || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 5
        startPeriod = 120
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.worker.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  volume {
    name = "efs-dags"
    efs_volume_configuration {
      file_system_id     = var.efs_file_system_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = var.efs_dags_access_point_id
      }
    }
  }

  volume {
    name = "efs-plugins"
    efs_volume_configuration {
      file_system_id     = var.efs_file_system_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = var.efs_plugins_access_point_id
      }
    }
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-worker-task" })
}

# Airflow Worker Service with Autoscaling
resource "aws_ecs_service" "worker" {
  name            = "${var.name_prefix}-worker"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = var.worker_desired_count
  launch_type     = var.enable_fargate_spot ? null : "FARGATE"

  dynamic "capacity_provider_strategy" {
    for_each = var.enable_fargate_spot ? [1] : []
    content {
      capacity_provider = "FARGATE"
      weight            = 1
      base              = 1
    }
  }

  dynamic "capacity_provider_strategy" {
    for_each = var.enable_fargate_spot ? [1] : []
    content {
      capacity_provider = "FARGATE_SPOT"
      weight            = 3
    }
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-worker-service" })
}

# Autoscaling for Workers
resource "aws_appautoscaling_target" "worker" {
  max_capacity       = var.worker_max_count
  min_capacity       = var.worker_min_count
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.worker.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "worker_cpu" {
  name               = "${var.name_prefix}-worker-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.worker.resource_id
  scalable_dimension = aws_appautoscaling_target.worker.scalable_dimension
  service_namespace  = aws_appautoscaling_target.worker.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "worker_memory" {
  name               = "${var.name_prefix}-worker-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.worker.resource_id
  scalable_dimension = aws_appautoscaling_target.worker.scalable_dimension
  service_namespace  = aws_appautoscaling_target.worker.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 80.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
