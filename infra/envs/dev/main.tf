# Dev Environment - Airflow 3.1 on ECS

terraform {
  required_version = ">= 1.12"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }

  backend "s3" {
    bucket = "pathwai-terraform-state"
    key    = "airflow-ecs/dev/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "airflow-ecs"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

locals {
  name_prefix = "pathwai-airflow-dev"
  tags = {
    Project     = "airflow-ecs"
    Environment = "dev"
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  name_prefix           = local.name_prefix
  vpc_cidr              = var.vpc_cidr
  private_subnet_cidrs  = var.private_subnet_cidrs
  availability_zones    = var.availability_zones
  region                = var.region
  tags                  = local.tags
}

# VPC Endpoints Module
module "vpc_endpoints" {
  source = "../../modules/vpc_endpoints"

  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
  vpc_cidr    = module.vpc.vpc_cidr
  subnet_ids  = module.vpc.private_subnet_ids
  region      = var.region
  tags        = local.tags
}

# ECS Cluster Module
module "ecs_cluster" {
  source = "../../modules/ecs_cluster"

  cluster_name        = "${local.name_prefix}-cluster"
  enable_fargate_spot = true  # Enable Spot for dev
  tags                = local.tags
}

# RDS Postgres Module
module "rds" {
  source = "../../modules/rds_postgres"

  name_prefix              = local.name_prefix
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnet_ids
  allowed_security_groups  = [module.ecs_services.ecs_tasks_security_group_id]
  postgres_version         = "16.1"
  instance_class           = "db.t4g.micro"
  allocated_storage        = 20
  database_name            = "airflow"
  master_username          = var.db_master_username
  master_password          = var.db_master_password
  backup_retention_period  = 7
  skip_final_snapshot      = true  # For dev only
  tags                     = local.tags
}

# ElastiCache Redis Module
module "redis" {
  source = "../../modules/redis"

  name_prefix             = local.name_prefix
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnet_ids
  allowed_security_groups = [module.ecs_services.ecs_tasks_security_group_id]
  redis_version           = "7.1"
  node_type               = "cache.t4g.micro"
  num_cache_nodes         = 1  # Single node for dev
  snapshot_retention_limit = 3
  tags                    = local.tags
}

# EFS Module
module "efs" {
  source = "../../modules/efs"

  name_prefix             = local.name_prefix
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnet_ids
  availability_zones      = var.availability_zones
  allowed_security_groups = [module.ecs_services.ecs_tasks_security_group_id]
  use_one_zone            = true  # One Zone for dev cost savings
  tags                    = local.tags
}

# ALB Module
module "alb" {
  source = "../../modules/alb"

  name_prefix                = local.name_prefix
  vpc_id                     = module.vpc.vpc_id
  vpc_cidr                   = module.vpc.vpc_cidr
  subnet_ids                 = module.vpc.private_subnet_ids
  certificate_arn            = var.alb_certificate_arn
  allowed_security_groups    = [module.ecs_services.ecs_tasks_security_group_id]
  enable_deletion_protection = false  # Disable for dev
  tags                       = local.tags
}

# IAM Module
module "iam" {
  source = "../../modules/iam"

  name_prefix   = local.name_prefix
  region        = var.region
  account_id    = var.account_id
  environment   = "dev"
  dags_bucket   = var.dags_bucket
  logs_bucket   = var.logs_bucket
  kms_key_arn   = module.rds.kms_key_id
  tags          = local.tags
}

# ECS Services Module
module "ecs_services" {
  source = "../../modules/ecs_service_airflow"

  name_prefix             = local.name_prefix
  region                  = var.region
  environment             = "dev"
  vpc_id                  = module.vpc.vpc_id
  vpc_cidr                = module.vpc.vpc_cidr
  private_subnet_ids      = module.vpc.private_subnet_ids
  ecs_cluster_id          = module.ecs_cluster.cluster_id
  ecs_cluster_name        = module.ecs_cluster.cluster_name
  alb_security_group_id   = module.alb.security_group_id
  target_group_arn        = module.alb.target_group_arn
  execution_role_arn      = module.iam.ecs_task_execution_role_arn
  web_task_role_arn       = module.iam.airflow_web_role_arn
  scheduler_task_role_arn = module.iam.airflow_scheduler_role_arn
  worker_task_role_arn    = module.iam.airflow_worker_role_arn
  efs_file_system_id      = module.efs.file_system_id
  efs_dags_access_point_id    = module.efs.dags_access_point_id
  efs_plugins_access_point_id = module.efs.plugins_access_point_id
  db_connection_string    = "postgresql+psycopg2://${var.db_master_username}:${var.db_master_password}@${module.rds.db_instance_address}:5432/${module.rds.db_name}"
  redis_connection_string = "rediss://${module.redis.redis_endpoint}:${module.redis.redis_port}/0"
  dags_bucket             = var.dags_bucket
  logs_bucket             = var.logs_bucket
  web_image               = "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/airflow-web:latest"
  scheduler_image         = "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/airflow-scheduler:latest"
  worker_image            = "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/airflow-worker:latest"
  sidecar_image           = "${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/sidecar-s3sync:latest"
  web_cpu                 = 512
  web_memory              = 1024
  web_desired_count       = 1
  scheduler_cpu           = 1024
  scheduler_memory        = 2048
  worker_cpu              = 1024
  worker_memory           = 2048
  worker_desired_count    = 1
  worker_min_count        = 0  # Scale to zero off-hours in dev
  worker_max_count        = 5
  worker_concurrency      = 4
  enable_fargate_spot     = true
  log_retention_days      = 7
  tags                    = local.tags
}
