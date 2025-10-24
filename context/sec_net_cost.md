# Security

- Private subnets only; deny egress except VPC endpoints.
- Secrets in Secrets Manager; no plaintext env.
- KMS CMKs for RDS/EFS/Redis/Logs/S3; key policies least-priv.
- SSO on web via ALB OIDC (internal access only).
- SGs: principle of least access; no `0.0.0.0/0`.

# IAM

- Separate task roles: web, scheduler, worker, sidecar.
- DAG-specific access via per-DAG policies (least-priv buckets/services).
- Run IAM Access Analyzer; block wildcards.

# Networking

- Endpoints: S3, ECR api+dkr, Logs, Events, STS, Secrets, SSM, EFS, KMS.
- Endpoint policies restricted to VPC and required ARNs.

# Cost

- Alert if NAT present (should never be).
- EFS One-Zone + lifecycle; Fargate Spot for workers in non-prod.
- CloudWatch/S3 retention set (e.g., 30/90/365 by env).

# Acceptance

No public routes. NAT $0. IAM Analyzer clean. OIDC auth working. Cost alarms in place.
