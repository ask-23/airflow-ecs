# OPA Policy: No NAT Gateways Allowed
# This policy MUST fail if any NAT gateway is detected

package terraform.analysis

import rego.v1

# Deny NAT gateways - CRITICAL POLICY
deny contains msg if {
    some resource in input.resource_changes
    resource.type == "aws_nat_gateway"
    msg := sprintf("CRITICAL: NAT gateway detected: %s - NAT gateways are not allowed in this architecture", [resource.address])
}

# Deny public subnets
deny contains msg if {
    some resource in input.resource_changes
    resource.type == "aws_subnet"
    resource.change.after.map_public_ip_on_launch == true
    msg := sprintf("ERROR: Public subnet detected: %s - Only private subnets allowed", [resource.address])
}

# Deny internet gateways attached to route tables (except for VPC endpoints)
deny contains msg if {
    some resource in input.resource_changes
    resource.type == "aws_route"
    contains(resource.change.after.gateway_id, "igw-")
    msg := sprintf("ERROR: Internet gateway route detected: %s - Use VPC endpoints instead", [resource.address])
}

# Warn if security groups allow 0.0.0.0/0
warn contains msg if {
    some resource in input.resource_changes
    resource.type == "aws_security_group"
    some rule in resource.change.after.ingress
    rule.cidr_blocks[_] == "0.0.0.0/0"
    msg := sprintf("WARNING: Security group allows 0.0.0.0/0: %s", [resource.address])
}
