# IAM Module - Task Roles for Airflow Services

terraform {
  required_version = ">= 1.12"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

# ECS Task Execution Role (for pulling images, logging)
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.name_prefix}-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, { Name = "${var.name_prefix}-ecs-task-execution" })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "secrets-access"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "kms:Decrypt"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:${var.name_prefix}/*",
          var.kms_key_arn
        ]
      }
    ]
  })
}

# Airflow Web Task Role
resource "aws_iam_role" "airflow_web" {
  name = "${var.name_prefix}-airflow-web"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, { Name = "${var.name_prefix}-airflow-web" })
}

resource "aws_iam_role_policy" "airflow_web" {
  name = "web-permissions"
  role = aws_iam_role.airflow_web.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.dags_bucket}",
          "arn:aws:s3:::${var.dags_bucket}/*"
        ]
      }
    ]
  })
}

# Airflow Scheduler Task Role
resource "aws_iam_role" "airflow_scheduler" {
  name = "${var.name_prefix}-airflow-scheduler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, { Name = "${var.name_prefix}-airflow-scheduler" })
}

resource "aws_iam_role_policy" "airflow_scheduler" {
  name = "scheduler-permissions"
  role = aws_iam_role.airflow_scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.dags_bucket}",
          "arn:aws:s3:::${var.dags_bucket}/*",
          "arn:aws:s3:::${var.logs_bucket}",
          "arn:aws:s3:::${var.logs_bucket}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/airflow/${var.name_prefix}/*"
      }
    ]
  })
}

# Airflow Worker Task Role
resource "aws_iam_role" "airflow_worker" {
  name = "${var.name_prefix}-airflow-worker"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, { Name = "${var.name_prefix}-airflow-worker" })
}

resource "aws_iam_role_policy" "airflow_worker" {
  name = "worker-permissions"
  role = aws_iam_role.airflow_worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.dags_bucket}/${var.environment}/*",
          "arn:aws:s3:::${var.logs_bucket}/${var.environment}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/airflow/${var.name_prefix}/*"
      }
    ]
  })
}

# S3 Sync Sidecar Task Role
resource "aws_iam_role" "s3_sync" {
  name = "${var.name_prefix}-s3-sync"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, { Name = "${var.name_prefix}-s3-sync" })
}

resource "aws_iam_role_policy" "s3_sync" {
  name = "s3-sync-permissions"
  role = aws_iam_role.s3_sync.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.dags_bucket}",
          "arn:aws:s3:::${var.dags_bucket}/${var.environment}/*"
        ]
      }
    ]
  })
}
