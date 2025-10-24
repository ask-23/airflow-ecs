Airflow: 3.1.x, CeleryExecutor.

ECS/Fargate: web, scheduler, workers; Redis broker (ElastiCache).

DAGs/plugins: EFS shared volume + s3-sync sidecar (pull-based), S3 as DAG source of truth.

Logging: S3 task logs, CloudWatch for service logs.

Networking: private subnets + VPC Interface Endpoints for S3/ECR/Logs/STS/Secrets/CloudWatchEvents/etc. No NAT Gateway.

Ingress: internal ALB to web/API; SSO required; TLS everywhere.

Health checks/timeouts: generous startPeriod (≥120s), ALB idle timeout ≥120s, /health for web/api; scheduler/worker use airflow jobs check.

Scaling: workers on queue depth + duration; allow scale-to-zero off-hours; optional Fargate Spot for workers.

Security: task-level IAM roles; encrypted EFS/RDS/Redis; KMS CMKs; secrets via Secrets Manager; least-priv policies.

Cost: alerts on NAT creation (shouldn’t exist), data-processed alarms, EFS lifecycle (One-Zone/IA).
