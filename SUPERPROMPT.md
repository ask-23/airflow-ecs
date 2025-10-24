Project: Rebuild Apache Airflow 3.1 on AWS ECS/Fargate (textbook, NAT-free, sidecar DAG sync).
Goal: Produce production-grade IaC + images + CI with guardrails so a new engineer can deploy in <60 minutes, and day-2 ops are boring.

Team & Responsibilities

Tech Lead/Architect: Owns ADRs and interfaces, enforces decisions, signs off acceptance.

Infra/IaC Engineer: Terraform modules + envs, VPC+endpoints (no NAT), ECS/Fargate, RDS, Redis, EFS, ALB, IAM.

App Packager: Dockerfiles for web/scheduler/worker/sidecar, Airflow 3.1 config, health checks, providers pinning.

Sec/Net/Cost: Least-priv IAM, TLS/SSO, Secrets Manager, KMS, logging/retention, autoscaling/Spot policy, cost alarms.

QA/SRE: Ephemeral env deploy, synthetic DAG tests, chaos/cold-start tests, dashboards/alarms, runbooks, rollback plan.

Non-Negotiable Requirements

Airflow 3.1, CeleryExecutor; Redis (ElastiCache) as broker; Postgres (RDS) for metadata; S3 for logs.

ECS/Fargate services: web, scheduler, worker(s). Internal ALB for web/API.

No NAT. Use VPC endpoints for S3, ECR (api+dkr), CloudWatch Logs, Events, STS, Secrets Manager, SSM, EFS, KMS.

DAGs/plugins on EFS shared volume. Sidecar s3-sync pulls from s3://<org>-airflow-dags/<env>/ every 30s with backoff + checksum/etag short-circuiting.

Health checks: startPeriod ≥120s; interval 30s; retries 5. ALB idle timeout ≥120s.

IAM: task-scoped roles; KMS-encrypted everything; least-priv policies reviewed by Access Analyzer.

CI: fmt → tflint → checkov → opa → docker build; deploy is gated by approvals.

Deliverables

docs/architecture.png + ADRs for executor, NAT-free endpoints, DAG sync pattern, scaling, logging.

Terraform modules + env overlays (dev/prod). Defaults NAT-free; toggle for public demo allowed but off by default.

Dockerfiles and entrypoints; pinned constraints.txt for Airflow providers.

GitHub Actions: validate.yml, deploy.yml, dag-sync.yml.

Synthetic DAG pack: quick, long, failing, external-sensor.

CloudWatch dashboards + alarms; runbooks in docs/runbooks/.

Definition of Done / Tests

One-click deploy to dev stands up fully working stack with no NAT.

Commit to /dags triggers S3 sync and DAG appears in UI in ≤60s.

Queue-based autoscaling proves scale-up (≥5 concurrent tasks) and off-hours scale-to-zero for workers.

Backups and retention set for RDS; restore instruсtions present.

Security scan passes and IAM policies are human-readable.

Conventions

Region: us-east-1 (make overridable).

Namespacing: <org>-airflow-<env>-<component>.

Least surprises: internal ALB + SSO; Secrets Manager for all secrets; KMS CMKs.

Prefer small images; only required providers.

Work Plan (milestones)

Scaffold repo + decision records

VPC + endpoints + SGs (no NAT)

RDS, Redis, EFS

ECS cluster + services + ALB

Docker images + health checks + sidecar

CI/CD + policy gates

Synthetic DAGs + dashboards + alarms

Runbooks + final acceptance

Output Format & Quality Bar

Open a PR with the full tree; include README.md quickstart.

Every module has variables README (tf-docs), example usage, and tests/validation.

Provide make dev targets to bootstrap and make destroy to tear down dev.

Keep comments terse and specific; link ADRs for rationale.

Now begin: Tech Lead drafts ADR skeleton + folder tree; Infra starts VPC/endpoints; Packager pegs Airflow 3.1 constraints and base Dockerfile; Sec/Net posts IAM policy templates; QA preps synthetic DAG pack and acceptance test list. Work in parallel; sync on interface contracts before coding cross-cuts.
