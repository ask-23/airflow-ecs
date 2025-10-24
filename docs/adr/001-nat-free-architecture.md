# ADR-001: NAT-Free Architecture for Apache Airflow on ECS

## Status
Accepted

## Context

Apache Airflow on AWS ECS requires connectivity to AWS services (ECR, CloudWatch, Secrets Manager, etc.) and potentially external resources. Traditional architectures use NAT Gateways to provide internet access from private subnets, but this introduces significant costs and operational complexity.

### Cost Analysis
- **NAT Gateway**: $0.045/hour + $0.045/GB = ~$32/month base + data transfer
- **High Availability**: 3 AZs × $32 = $96/month minimum
- **Data Transfer**: Variable, typically $50-100/month
- **Total NAT Cost**: $150-200/month for HA setup

### Requirements
1. ECS tasks in private subnets (no public IPs)
2. Access to AWS services (ECR, CloudWatch, Secrets Manager, KMS, S3)
3. No internet access required for core Airflow functionality
4. Minimize operational costs
5. Maintain security posture
6. Support DAG development workflows

## Decision

Implement a **NAT-free architecture** using AWS VPC Endpoints (PrivateLink) for all AWS service connectivity.

### Architecture Components

1. **VPC Endpoints (Interface)**
   - ECR API endpoint (`com.amazonaws.region.ecr.api`)
   - ECR Docker endpoint (`com.amazonaws.region.ecr.dkr`)
   - CloudWatch Logs endpoint (`com.amazonaws.region.logs`)
   - Secrets Manager endpoint (`com.amazonaws.region.secretsmanager`)
   - KMS endpoint (`com.amazonaws.region.kms`)
   - STS endpoint (`com.amazonaws.region.sts`)

2. **VPC Endpoints (Gateway)**
   - S3 endpoint (`com.amazonaws.region.s3`)

3. **Private DNS**
   - Enable private DNS for all interface endpoints
   - AWS service calls resolve to VPC endpoint IPs

4. **Security Groups**
   - VPC endpoint security group allows HTTPS (443) from ECS tasks
   - ECS task security group allows outbound to VPC endpoints
   - No internet gateway required

### Connectivity Flow

```
ECS Task (Private Subnet)
    ↓ HTTPS (443)
VPC Endpoint Security Group
    ↓ PrivateLink
AWS Service (ECR/CloudWatch/Secrets Manager/etc)
```

### Cost Comparison

**NAT Gateway Architecture:**
- 3× NAT Gateway: $96/month
- Data transfer: $50-100/month
- **Total: $150-200/month**

**VPC Endpoint Architecture:**
- 6× Interface endpoints: 6 × $7.20/month = $43.20/month
- 1× Gateway endpoint (S3): $0/month
- Data processing: 6 × $0.01/GB ≈ $10-20/month
- **Total: $50-65/month**

**Savings: ~$100-150/month (60-70% reduction)**

## Consequences

### Positive

1. **Cost Savings**
   - 60-70% reduction in networking costs
   - Predictable monthly expenses
   - No data transfer charges for S3 gateway endpoint

2. **Security**
   - All traffic stays within AWS network
   - No internet gateway required
   - Reduced attack surface
   - Private DNS prevents DNS exfiltration

3. **Performance**
   - Lower latency to AWS services
   - No NAT bottleneck
   - Consistent network performance

4. **Reliability**
   - No single point of failure (endpoints in all AZs)
   - AWS-managed infrastructure
   - Built-in redundancy

### Negative

1. **Limited Internet Access**
   - Cannot install packages from PyPI during runtime
   - Cannot download files from internet
   - Cannot integrate with external webhooks/APIs
   - **Mitigation**: Pre-build Docker images with all dependencies

2. **Endpoint Costs**
   - Per-endpoint hourly charges ($0.01/hour)
   - Data processing charges ($0.01/GB)
   - **Mitigation**: Still cheaper than NAT Gateway

3. **Additional Configuration**
   - More complex Terraform setup
   - Security group management
   - DNS configuration
   - **Mitigation**: Automated via Terraform modules

4. **Operational Changes**
   - DAG development requires pre-building
   - Custom operators must be in Docker image
   - Testing workflow adjustments
   - **Mitigation**: CI/CD pipeline for DAG validation

### Neutral

1. **VPC Endpoint Coverage**
   - Most AWS services support VPC endpoints
   - Growing list of supported services
   - Regional availability varies

2. **Hybrid Scenarios**
   - Can add NAT Gateway later if needed
   - Can use both approaches simultaneously
   - Flexible architecture

## Implementation Plan

### Phase 1: VPC Endpoints (Week 1)
- [x] Create interface endpoints for ECR, CloudWatch, Secrets Manager, KMS, STS
- [x] Create gateway endpoint for S3
- [x] Configure security groups
- [x] Enable private DNS

### Phase 2: Docker Image (Week 1)
- [x] Build Airflow image with all dependencies
- [x] Include custom operators and providers
- [x] Push to ECR
- [x] Test image locally

### Phase 3: ECS Deployment (Week 2)
- [x] Deploy ECS cluster in private subnets
- [x] Configure task definitions with VPC endpoints
- [x] Test connectivity to AWS services
- [x] Verify DAG execution

### Phase 4: Validation (Week 2)
- [ ] Validate no NAT gateway in infrastructure
- [ ] Test all AWS service integrations
- [ ] Verify security group rules
- [ ] Load test and performance validation

## Alternatives Considered

### 1. NAT Gateway Architecture
**Pros:**
- Simple configuration
- Unrestricted internet access
- Familiar pattern

**Cons:**
- High costs ($150-200/month)
- Additional infrastructure to manage
- Single point of failure per AZ
- Higher security risk

**Decision:** Rejected due to cost and security concerns

### 2. Hybrid Architecture (NAT + VPC Endpoints)
**Pros:**
- Best of both worlds
- Gradual migration path
- Fallback option

**Cons:**
- Highest cost (VPC endpoints + NAT)
- Complex routing
- Unclear use case for internet access

**Decision:** Rejected; no current need for internet access

### 3. Public Subnets with Security Groups
**Pros:**
- No additional costs
- Simple networking

**Cons:**
- Security risk (public IPs)
- Not compliant with security policies
- Exposed to internet threats

**Decision:** Rejected due to security requirements

### 4. AWS PrivateLink Only (No S3 Gateway)
**Pros:**
- Consistent interface endpoint approach

**Cons:**
- S3 interface endpoint costs more than gateway
- No benefit over gateway endpoint

**Decision:** Rejected; use S3 gateway endpoint for cost savings

## Validation Criteria

### Success Metrics
- [ ] Zero NAT Gateways deployed
- [ ] All ECS tasks start successfully in private subnets
- [ ] All AWS service calls succeed through VPC endpoints
- [ ] DAG sync from S3/EFS works within 60 seconds
- [ ] Health checks stable (no flapping)
- [ ] Cost reduction of 60%+ vs NAT architecture
- [ ] Security groups follow least privilege
- [ ] IAM Access Analyzer shows no broad grants
- [ ] All resources encrypted with KMS CMK

### Testing Plan
1. **Connectivity Tests**
   ```bash
   # From ECS task, verify AWS service access
   aws ecr get-login-password
   aws secretsmanager get-secret-value --secret-id test
   aws logs describe-log-groups
   aws s3 ls
   ```

2. **Performance Tests**
   - Measure task startup time
   - Verify DAG parsing time
   - Test worker task execution latency

3. **Security Tests**
   - Run IAM Access Analyzer
   - Verify security group rules
   - Check KMS encryption
   - Test least-privilege IAM

4. **Cost Validation**
   - Monitor AWS Cost Explorer
   - Compare actual vs projected costs
   - Track VPC endpoint data processing

## Risks and Mitigations

### Risk 1: Missing VPC Endpoint
**Impact:** Task fails to access AWS service
**Likelihood:** Low
**Mitigation:**
- Comprehensive endpoint coverage in Terraform
- Testing plan validates all endpoints
- Monitor CloudWatch Logs for connection errors

### Risk 2: Security Group Misconfiguration
**Impact:** Tasks cannot connect to endpoints
**Likelihood:** Medium
**Mitigation:**
- Automated Terraform security group rules
- Least-privilege by default
- Validation tests before production

### Risk 3: Cost Overrun from Data Processing
**Impact:** Higher than expected endpoint costs
**Likelihood:** Low
**Mitigation:**
- Monitor CloudWatch metrics for endpoint usage
- Set up billing alarms
- Optimize data transfer patterns

### Risk 4: External Integration Requirement
**Impact:** Need internet access for webhooks/APIs
**Likelihood:** Medium
**Mitigation:**
- Document current lack of internet access
- Design pattern: external Lambda for webhooks
- Can add NAT Gateway if truly needed

### Risk 5: Operational Complexity
**Impact:** Steeper learning curve for team
**Likelihood:** Medium
**Mitigation:**
- Comprehensive documentation
- Runbooks for common operations
- Training sessions for team

## References

- [AWS VPC Endpoints Documentation](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- [AWS PrivateLink Pricing](https://aws.amazon.com/privatelink/pricing/)
- [NAT Gateway Pricing](https://aws.amazon.com/vpc/pricing/)
- [ECS Task Networking](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-networking.html)
- [Apache Airflow on ECS Best Practices](https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/deploy-apache-airflow-on-amazon-ecs-fargate.html)

## Approval

- **Author**: Platform Engineering Team
- **Date**: 2024-01-15
- **Approved By**: [Architecture Review Board]
- **Review Date**: 2024-01-22

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2024-01-15 | Platform Eng | Initial version |
| 1.1 | 2024-01-22 | Platform Eng | Added validation criteria |
