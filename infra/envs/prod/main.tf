terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Backend config provided via CLI
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "prod"
      Project     = "airflow-ecs"
      ManagedBy   = "terraform"
      Repository  = "airflow-ecs"
    }
  }
}

module "vpc" {
  source = "../../modules/vpc"

  environment         = "prod"
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  # Private subnets only - no NAT
  enable_nat_gateway = false
  enable_s3_endpoint = true

  tags = {
    Environment = "prod"
  }
}

module "security" {
  source = "../../modules/security"

  environment = "prod"
  vpc_id      = module.vpc.vpc_id
  vpc_cidr    = var.vpc_cidr

  tags = {
    Environment = "prod"
  }
}

module "rds" {
  source = "../../modules/rds"

  environment           = "prod"
  vpc_id               = module.vpc.vpc_id
  subnet_ids           = module.vpc.private_subnet_ids
  security_group_ids   = [module.security.rds_security_group_id]

  instance_class       = var.rds_instance_class
  allocated_storage    = var.rds_allocated_storage
  multi_az            = var.rds_multi_az
  backup_retention    = var.rds_backup_retention

  tags = {
    Environment = "prod"
  }
}

module "ecs" {
  source = "../../modules/ecs"

  environment         = "prod"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security.ecs_security_group_id]

  cluster_name       = var.ecs_cluster_name
  task_cpu          = var.ecs_task_cpu
  task_memory       = var.ecs_task_memory
  desired_count     = var.ecs_desired_count

  airflow_image     = var.airflow_image
  db_host          = module.rds.endpoint
  db_name          = var.db_name
  db_username      = var.db_username

  dags_bucket      = module.s3.dags_bucket_name
  logs_bucket      = module.s3.logs_bucket_name

  tags = {
    Environment = "prod"
  }
}

module "s3" {
  source = "../../modules/s3"

  environment    = "prod"
  aws_account_id = var.aws_account_id

  vpc_id = module.vpc.vpc_id

  tags = {
    Environment = "prod"
  }
}

module "monitoring" {
  source = "../../modules/monitoring"

  environment     = "prod"
  cluster_name    = module.ecs.cluster_name
  service_name    = module.ecs.service_name

  log_retention_days = var.log_retention_days

  # Production alerting
  enable_alarms           = true
  alarm_email            = var.alarm_email
  cpu_threshold          = 80
  memory_threshold       = 80
  error_rate_threshold   = 5

  tags = {
    Environment = "prod"
  }
}
