# Scope

Provision NAT-free AWS infra for Airflow 3.1 on ECS/Fargate: VPC(+endpoints), ECS cluster/services, ALB, RDS(Postgres), ElastiCache Redis, EFS, IAM.

# Constraints (non-negotiable)

- Private subnets only; **NO NAT**.
- Interface VPC Endpoints: S3, ECR (api+dkr), Logs, Events, STS, Secrets Manager, SSM, EFS, KMS.
- TLS everywhere; ALB internal; SSO on web.
- KMS CMKs for RDS/EFS/Redis/Logs/S3.
- Least-priv IAM; task roles, not instance roles.

# Deliverables

- Terraform **modules**: vpc, vpc_endpoints, ecs_cluster, ecs_service_airflow, rds_postgres, redis, efs, alb, iam.
- **env overlays** (dev/prod) with tfvars.
- Security groups & routing that pass “no-egress” checks.

# Interfaces

- ECS services: `airflow-web`, `airflow-scheduler`, `airflow-worker`.
- Shared EFS mount: `/opt/airflow/dags`, `/opt/airflow/plugins`.
- Sidecar mount: same EFS path. Bucket: `s3://<org>-airflow-dags/<env>/`.
- ALB target health: `/health` (web/api).

# Health/Timeouts

- container `startPeriod>=120s`, `interval=30s`, `retries=5`.
- ALB idle timeout `>=120s`.

# Scaling

- Workers: AS on Celery queue depth/duration; allow scale-to-zero off-hours.
- Optional Fargate Spot for workers (non-prod by default).

# Observability

- CloudWatch logs for services; S3 task logs partitioned by date.
- Metrics/alarms: scheduler heartbeat, queue depth, ALB 5xx, task failure rate, worker desired vs running.

# Cost Guardrails

- Fail pipeline if NAT detected.
- Endpoint-only egress; EFS One-Zone + lifecycle to IA where safe.

# Acceptance

Infra provisions cleanly with `tflint`, `checkov`, OPA, IAM Access Analyzer = OK; no public subnets; endpoints reachable; ALB internal.
