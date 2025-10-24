# EFS Module for shared DAGs and plugins

terraform {
  required_version = ">= 1.12"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

resource "aws_security_group" "efs" {
  name_prefix = "${var.name_prefix}-efs-"
  description = "Security group for EFS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "NFS from ECS"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-efs-sg" })
}

resource "aws_kms_key" "efs" {
  description             = "KMS key for EFS encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-efs-kms" })
}

resource "aws_kms_alias" "efs" {
  name          = "alias/${var.name_prefix}-efs"
  target_key_id = aws_kms_key.efs.key_id
}

resource "aws_efs_file_system" "main" {
  encrypted  = true
  kms_key_id = aws_kms_key.efs.arn

  performance_mode                = "generalPurpose"
  throughput_mode                 = "bursting"
  availability_zone_name          = var.use_one_zone ? var.availability_zones[0] : null

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-efs" })
}

resource "aws_efs_mount_target" "main" {
  count = var.use_one_zone ? 1 : length(var.subnet_ids)

  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = var.use_one_zone ? var.subnet_ids[0] : var.subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_access_point" "dags" {
  file_system_id = aws_efs_file_system.main.id

  posix_user {
    gid = 50000
    uid = 50000
  }

  root_directory {
    path = "/dags"
    creation_info {
      owner_gid   = 50000
      owner_uid   = 50000
      permissions = "755"
    }
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-dags-ap" })
}

resource "aws_efs_access_point" "plugins" {
  file_system_id = aws_efs_file_system.main.id

  posix_user {
    gid = 50000
    uid = 50000
  }

  root_directory {
    path = "/plugins"
    creation_info {
      owner_gid   = 50000
      owner_uid   = 50000
      permissions = "755"
    }
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-plugins-ap" })
}
