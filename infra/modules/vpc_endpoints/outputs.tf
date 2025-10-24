output "endpoints_security_group_id" {
  description = "Security group ID for VPC endpoints"
  value       = aws_security_group.endpoints.id
}

output "endpoint_ids" {
  description = "Map of endpoint IDs"
  value = {
    ecr_api        = aws_vpc_endpoint.ecr_api.id
    ecr_dkr        = aws_vpc_endpoint.ecr_dkr.id
    logs           = aws_vpc_endpoint.logs.id
    events         = aws_vpc_endpoint.events.id
    sts            = aws_vpc_endpoint.sts.id
    secretsmanager = aws_vpc_endpoint.secretsmanager.id
    ssm            = aws_vpc_endpoint.ssm.id
    efs            = aws_vpc_endpoint.efs.id
    kms            = aws_vpc_endpoint.kms.id
  }
}
