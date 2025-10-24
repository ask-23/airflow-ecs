package terraform

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Security guardrails for Airflow on ECS infrastructure

# Deny if S3 bucket doesn't have encryption
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_s3_bucket"
    not has_encryption(resource)
    msg := sprintf(
        "🔒 SECURITY: S3 bucket '%s' must have server-side encryption enabled",
        [resource.name]
    )
}

has_encryption(resource) {
    resource.values.server_side_encryption_configuration[_]
}

# Deny if S3 bucket is publicly accessible
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_s3_bucket_public_access_block"
    resource.values.block_public_acls == false
    msg := sprintf(
        "🔒 SECURITY: S3 bucket '%s' must block public ACLs",
        [resource.name]
    )
}

deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_s3_bucket_public_access_block"
    resource.values.block_public_policy == false
    msg := sprintf(
        "🔒 SECURITY: S3 bucket '%s' must block public policies",
        [resource.name]
    )
}

# Deny if security group allows unrestricted ingress
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_security_group_rule"
    resource.values.type == "ingress"
    resource.values.cidr_blocks[_] == "0.0.0.0/0"
    not allowed_public_port(resource.values.from_port)
    msg := sprintf(
        "🔒 SECURITY: Security group rule '%s' allows unrestricted access from 0.0.0.0/0 on port %d",
        [resource.name, resource.values.from_port]
    )
}

# Only allow specific ports for public access
allowed_public_port(443) = true
allowed_public_port(80) = true

# Deny if ECS task doesn't use task role
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_ecs_task_definition"
    not resource.values.task_role_arn
    msg := sprintf(
        "🔒 SECURITY: ECS task definition '%s' must have a task role assigned",
        [resource.name]
    )
}

# Deny if RDS instance is publicly accessible
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_db_instance"
    resource.values.publicly_accessible == true
    msg := sprintf(
        "🔒 SECURITY: RDS instance '%s' must not be publicly accessible",
        [resource.name]
    )
}

# Deny if RDS instance doesn't have encryption
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_db_instance"
    resource.values.storage_encrypted == false
    msg := sprintf(
        "🔒 SECURITY: RDS instance '%s' must have storage encryption enabled",
        [resource.name]
    )
}

# Warn if CloudWatch log retention is less than 30 days
warn[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_cloudwatch_log_group"
    resource.values.retention_in_days < 30
    msg := sprintf(
        "⚠️  WARNING: Log group '%s' has retention less than 30 days (%d days)",
        [resource.name, resource.values.retention_in_days]
    )
}

# Deny if IAM policy allows full admin access
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_iam_policy"
    contains(resource.values.policy, "\"*\"")
    contains(resource.values.policy, "\"Effect\": \"Allow\"")
    msg := sprintf(
        "🔒 SECURITY: IAM policy '%s' appears to grant overly broad permissions (Action: *)",
        [resource.name]
    )
}

# Verify secrets are stored in Secrets Manager or Parameter Store
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_ecs_task_definition"
    container_def := resource.values.container_definitions
    contains(container_def, "environment")
    contains(lower(container_def), "password")
    not contains(container_def, "secrets")
    msg := sprintf(
        "🔒 SECURITY: ECS task '%s' appears to have passwords in environment variables. Use secrets from Secrets Manager instead.",
        [resource.name]
    )
}

# Deny if VPC doesn't have flow logs enabled
deny[msg] {
    vpc := input.planned_values.root_module.resources[_]
    vpc.type == "aws_vpc"
    vpc_id := vpc.values.id

    # Check if flow log exists for this VPC
    count([fl |
        fl := input.planned_values.root_module.resources[_]
        fl.type == "aws_flow_log"
        fl.values.vpc_id == vpc_id
    ]) == 0

    msg := sprintf(
        "🔒 SECURITY: VPC '%s' must have VPC Flow Logs enabled for network monitoring",
        [vpc.name]
    )
}

# Deny if ALB doesn't have access logging enabled
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_lb"
    not has_access_logs(resource)
    msg := sprintf(
        "🔒 SECURITY: Load balancer '%s' must have access logging enabled",
        [resource.name]
    )
}

has_access_logs(resource) {
    resource.values.access_logs[_].enabled == true
}

# Verify KMS keys are used for encryption
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_s3_bucket_server_side_encryption_configuration"
    rule := resource.values.rule[_]
    not rule.apply_server_side_encryption_by_default[_].kms_master_key_id
    msg := sprintf(
        "🔒 SECURITY: S3 bucket encryption should use KMS keys for enhanced security",
        [resource.name]
    )
}

# Account verification
deny[msg] {
    # Extract account ID from resource ARNs
    resource := input.planned_values.root_module.resources[_]
    arn := resource.values.arn
    arn != null

    # Check if account ID in ARN matches expected
    not contains(arn, "381492153064")

    msg := sprintf(
        "🔒 SECURITY: Resource '%s' ARN doesn't match expected AWS account 381492153064",
        [resource.name]
    )
}
