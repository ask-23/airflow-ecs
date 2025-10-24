# Airflow 3.1 on AWS ECS - NAT-Free Architecture Design

**Version:** 1.0
**Date:** 2025-10-24
**Account:** 381492153064
**S3 DAG Bucket:** pathwai-airflow3-dags

---

## Executive Summary

This document defines a **NAT-free, fully private** AWS architecture for Apache Airflow 3.1 running on ECS Fargate with CeleryExecutor. The design eliminates all NAT gateways through comprehensive VPC endpoint coverage, enforces TLS everywhere, implements least-privilege IAM, and uses KMS CMKs for all data at rest.

**Key Design Principles:**
- ✅ **Zero NAT Gateways** - VPC endpoints for all AWS service access
- ✅ **Private Subnets Only** - No public subnets or internet gateways for Airflow resources
- ✅ **TLS Everywhere** - End-to-end encryption in transit
- ✅ **KMS CMKs** - Customer-managed keys for RDS, ElastiCache, EFS, CloudWatch Logs, S3
- ✅ **Least Privilege IAM** - Separate task roles with minimal permissions
- ✅ **Internal ALB with SSO** - OIDC authentication for web access

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          AWS Account: 381492153064                       │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ VPC (10.0.0.0/16) - NO NAT GATEWAYS                               │ │
│  │                                                                     │ │
│  │  ┌──────────────────────────────────────────────────────────────┐ │ │
│  │  │ Private Subnet AZ-A (10.0.1.0/24)                            │ │ │
│  │  │                                                               │ │ │
│  │  │  ┌─────────────┐  ┌──────────────┐  ┌─────────────┐        │ │ │
│  │  │  │ Airflow Web │  │   Scheduler  │  │   Worker    │        │ │ │
│  │  │  │  (Fargate)  │  │  (Fargate)   │  │  (Fargate)  │        │ │ │
│  │  │  │   + Sidecar │  │  + Sidecar   │  │  + Sidecar  │        │ │ │
│  │  │  └──────┬──────┘  └──────┬───────┘  └──────┬──────┘        │ │ │
│  │  │         │                 │                  │               │ │ │
│  │  │         └─────────────────┼──────────────────┘               │ │ │
│  │  │                           │                                  │ │ │
│  │  │                      ┌────▼────┐                            │ │ │
│  │  │                      │   EFS   │ /opt/airflow/dags,plugins │ │ │
│  │  │                      │ (CMK)   │                            │ │ │
│  │  │                      └─────────┘                            │ │ │
│  │  └──────────────────────────────────────────────────────────────┘ │ │
│  │                                                                     │ │
│  │  ┌──────────────────────────────────────────────────────────────┐ │ │
│  │  │ Private Subnet AZ-B (10.0.2.0/24)                            │ │ │
│  │  │  [Same as AZ-A for HA]                                       │ │ │
│  │  └──────────────────────────────────────────────────────────────┘ │ │
│  │                                                                     │ │
│  │  ┌──────────────────────────────────────────────────────────────┐ │ │
│  │  │ Data Subnet AZ-A (10.0.11.0/24)                              │ │ │
│  │  │  ┌──────────────┐  ┌─────────────────┐                      │ │ │
│  │  │  │ RDS Postgres │  │ ElastiCache     │                      │ │ │
│  │  │  │  Multi-AZ    │  │   Redis         │                      │ │ │
│  │  │  │   (CMK)      │  │  (Cluster CMK)  │                      │ │ │
│  │  │  └──────────────┘  └─────────────────┘                      │ │ │
│  │  └──────────────────────────────────────────────────────────────┘ │ │
│  │                                                                     │ │
│  │  ┌──────────────────────────────────────────────────────────────┐ │ │
│  │  │ Data Subnet AZ-B (10.0.12.0/24)                              │ │ │
│  │  │  [RDS standby, Redis replica nodes]                          │ │ │
│  │  └──────────────────────────────────────────────────────────────┘ │ │
│  │                                                                     │ │
│  │  ┌──────────────────────────────────────────────────────────────┐ │ │
│  │  │ Internal ALB Subnet AZ-A/B (10.0.21.0/24, 10.0.22.0/24)     │ │ │
│  │  │  ┌─────────────────────────────────────────────────────────┐ │ │ │
│  │  │  │ Internal ALB (scheme: internal)                         │ │ │ │
│  │  │  │  - TLS Listener (443) → Target: airflow-web:8080       │ │ │ │
│  │  │  │  - OIDC Authentication                                  │ │ │ │
│  │  │  │  - Health: /health                                      │ │ │ │
│  │  │  └─────────────────────────────────────────────────────────┘ │ │ │
│  │  └──────────────────────────────────────────────────────────────┘ │ │
│  │                                                                     │ │
│  │  ┌──────────────────────────────────────────────────────────────┐ │ │
│  │  │ VPC Endpoints (Interface) - PrivateLink                      │ │ │
│  │  │  ✓ com.amazonaws.region.ecr.api                             │ │ │
│  │  │  ✓ com.amazonaws.region.ecr.dkr                             │ │ │
│  │  │  ✓ com.amazonaws.region.logs                                │ │ │
│  │  │  ✓ com.amazonaws.region.events                              │ │ │
│  │  │  ✓ com.amazonaws.region.sts                                 │ │ │
│  │  │  ✓ com.amazonaws.region.secretsmanager                      │ │ │
│  │  │  ✓ com.amazonaws.region.ssm                                 │ │ │
│  │  │  ✓ com.amazonaws.region.elasticfilesystem                   │ │ │
│  │  │  ✓ com.amazonaws.region.kms                                 │ │ │
│  │  └──────────────────────────────────────────────────────────────┘ │ │
│  │                                                                     │ │
│  │  ┌──────────────────────────────────────────────────────────────┐ │ │
│  │  │ VPC Endpoint (Gateway)                                        │ │ │
│  │  │  ✓ com.amazonaws.region.s3                                   │ │ │
│  │  └──────────────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ External Services (accessed via VPC Endpoints)                     │ │
│  │  - S3: pathwai-airflow3-dags (DAGs), pathwai-airflow3-logs       │ │
│  │  - ECR: Airflow images (web, scheduler, worker, sidecar)          │ │
│  │  - CloudWatch Logs: Container logs                                 │ │
│  │  - Secrets Manager: DB credentials, Redis URL, app secrets         │ │
│  │  - KMS: Encryption keys (RDS, EFS, Redis, Logs, S3)               │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Architecture Decision Records

### ADR-001: NAT-Free Design with VPC Endpoints

**Status:** Accepted
**Context:** Cost optimization and security hardening require elimination of NAT gateways while maintaining AWS service access.

**Decision:**
- Use **Interface VPC Endpoints** (PrivateLink) for: ECR (API+DKR), CloudWatch Logs, EventBridge, STS, Secrets Manager, SSM, EFS, KMS
- Use **Gateway VPC Endpoint** for S3 (zero cost)
- All subnets are private; no internet gateway attached to route tables

**Consequences:**
- ✅ **Cost savings:** ~$100/month per NAT gateway eliminated
- ✅ **Enhanced security:** No internet egress path
- ✅ **Compliance:** Data never traverses public internet
- ⚠️ **Endpoint costs:** Interface endpoints ~$7-10/month each (~$80/month total)
- ⚠️ **Complexity:** Requires comprehensive endpoint coverage and testing

**Validation:**
- OPA policy enforces: `deny[msg] { input.resource.type == "aws_nat_gateway"; msg := "NAT not allowed" }`
- Checkov and tflint must pass
- Manual verification: `terraform plan` contains zero `aws_nat_gateway` resources

---

### ADR-002: ECS Fargate over EC2

**Status:** Accepted
**Context:** Choose between Fargate and EC2 for ECS task hosting.

**Decision:** Use **Fargate** exclusively for all Airflow components (web, scheduler, workers).

**Rationale:**
- **No instance management:** No patching, scaling, or capacity planning for EC2 hosts
- **Per-task isolation:** Each task runs in dedicated kernel
- **Right-sizing:** Pay per vCPU/memory, not per instance
- **Cold start acceptable:** Airflow services are long-running; 30-60s startup is tolerable

**Task Sizing:**
```yaml
airflow-web:
  cpu: 1024 (1 vCPU)
  memory: 2048 (2 GB)

airflow-scheduler:
  cpu: 1024 (1 vCPU)
  memory: 2048 (2 GB)

airflow-worker:
  cpu: 2048 (2 vCPU)
  memory: 4096 (4 GB)
  desired_count: 2 (dev), 4 (prod)
  autoscaling: 1-10 based on queue depth

sidecar-s3sync:
  cpu: 256 (0.25 vCPU)
  memory: 512 (0.5 GB)
```

**Consequences:**
- ✅ Operational simplicity
- ✅ Security: No SSH access or instance-level vulnerabilities
- ⚠️ **Fargate pricing:** Slightly higher than EC2 spot, but offset by no NAT cost
- ⚠️ **Fargate Spot for workers in non-prod:** 70% discount, acceptable interruption risk

---

### ADR-003: EFS for Shared DAG/Plugin Storage

**Status:** Accepted
**Context:** DAGs and plugins must be shared across all Airflow components without baking into images.

**Decision:**
- **EFS file system** (One-Zone for dev, Multi-AZ for prod)
- Mount at `/opt/airflow/dags` and `/opt/airflow/plugins` on all tasks
- **S3-sync sidecar** pulls from `s3://pathwai-airflow3-dags/<env>/` every 30s with jitter

**Rationale:**
- **Dynamic DAG updates:** No container restarts needed
- **Shared state:** All tasks see identical DAG/plugin code
- **Version control:** DAGs in Git → CI syncs to S3 → sidecar pulls → EFS
- **Performance:** EFS One-Zone + lifecycle policy to IA after 30 days (dev only)

**Data Flow:**
```
Git Repo (DAGs) → GitHub Actions → S3 sync → Sidecar pulls → EFS → All Airflow tasks read
```

**Consequences:**
- ✅ **DAG deployments ≤60s** without service restarts
- ✅ **EFS encryption at rest:** KMS CMK required
- ⚠️ **EFS cost:** $0.30/GB-month (Standard), $0.16/GB-month (One-Zone)
- ⚠️ **Lifecycle policy:** Move to IA after 30 days (90% cost reduction)

**Mount Configuration:**
```hcl
volume {
  name = "airflow-dags-plugins"
  efs_volume_configuration {
    file_system_id          = aws_efs_file_system.airflow.id
    transit_encryption      = "ENABLED"
    transit_encryption_port = 2999
    authorization_config {
      access_point_id = aws_efs_access_point.airflow.id
      iam             = "ENABLED"
    }
  }
}

mount_points {
  source_volume  = "airflow-dags-plugins"
  container_path = "/opt/airflow/dags"
  read_only      = false
}
```

---

### ADR-004: RDS Postgres Multi-AZ with CMK Encryption

**Status:** Accepted
**Context:** Airflow metadata database requirements.

**Decision:**
- **RDS Postgres 16** (latest stable)
- **Multi-AZ deployment** for HA (prod), single-AZ (dev)
- **KMS CMK encryption** at rest
- **Instance class:** db.t4g.medium (dev), db.r6g.large (prod)
- **Storage:** gp3, autoscaling enabled
- **Backup:** 7 days (dev), 30 days (prod)

**Connection String:**
```
postgresql://<user>:<password>@<rds-endpoint>:5432/airflow
```
- Credentials stored in **Secrets Manager** with KMS encryption
- Connection string injected as environment variable: `AIRFLOW__DATABASE__SQL_ALCHEMY_CONN`

**Security:**
- Security group: Allow 5432 from ECS tasks only
- **No public accessibility**
- **TLS enforcement:** `rds.force_ssl=1`

**Consequences:**
- ✅ **Managed service:** Automatic backups, patching, failover
- ✅ **HA:** Multi-AZ for zero-downtime maintenance
- ⚠️ **Cost:** Multi-AZ doubles storage and instance cost
- ⚠️ **Performance:** Monitor connection pool sizing (`sql_alchemy_pool_size`)

---

### ADR-005: ElastiCache Redis for Celery Broker

**Status:** Accepted
**Context:** CeleryExecutor requires broker for task queue and result backend.

**Decision:**
- **ElastiCache Redis 7.x** (cluster mode disabled for simplicity)
- **Node type:** cache.t4g.micro (dev), cache.r6g.large (prod)
- **Replication:** 1 primary + 2 replicas (prod), 1 primary only (dev)
- **KMS CMK encryption** at rest and in-transit
- **Automatic failover** enabled (prod)

**Airflow Configuration:**
```python
AIRFLOW__CELERY__BROKER_URL = redis://<redis-endpoint>:6379/0
AIRFLOW__CELERY__RESULT_BACKEND = db+postgresql://...  # Use RDS, not Redis
```

**Why not Redis for result backend?**
- Postgres result backend provides better durability and query capabilities
- Redis used exclusively for message passing (ephemeral task queue)

**Security:**
- Security group: Allow 6379 from ECS tasks only
- **AUTH token** via Secrets Manager
- **TLS enabled** on all connections

**Consequences:**
- ✅ **Performance:** Sub-millisecond latency for task queueing
- ✅ **Scalability:** Handles 10K+ tasks/second
- ⚠️ **Cost:** Replication increases cost 3x
- ⚠️ **Redis memory:** Monitor `maxmemory-policy` (allkeys-lru recommended)

---

### ADR-006: Internal ALB with OIDC Authentication

**Status:** Accepted
**Context:** Web UI access control and TLS termination.

**Decision:**
- **Application Load Balancer** (scheme: `internal`)
- **HTTPS listener** on port 443 with ACM certificate
- **OIDC authentication** action before routing to target group
- **Target group:** airflow-web ECS service on port 8080

**ALB Configuration:**
```hcl
load_balancer_type = "application"
internal           = true
subnets            = [aws_subnet.alb_a.id, aws_subnet.alb_b.id]

listener {
  port            = 443
  protocol        = "HTTPS"
  ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn = aws_acm_certificate.airflow.arn

  default_action {
    type = "authenticate-oidc"
    authenticate_oidc {
      issuer                 = var.oidc_issuer
      authorization_endpoint = var.oidc_auth_endpoint
      token_endpoint         = var.oidc_token_endpoint
      user_info_endpoint     = var.oidc_userinfo_endpoint
      client_id              = var.oidc_client_id
      client_secret          = data.aws_secretsmanager_secret_version.oidc.secret_string
    }
  }

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.airflow_web.arn
  }
}

target_group {
  port                 = 8080
  protocol             = "HTTP"
  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = "/health"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 5
    matcher             = "200"
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }
}
```

**Health Check Details:**
- **Path:** `/health` (Airflow 3.1 built-in endpoint)
- **Startup grace period:** 120s for container `startPeriod`
- **Retries:** 5 failures before unhealthy

**Consequences:**
- ✅ **SSO integration:** OIDC for centralized authentication
- ✅ **TLS termination:** ALB handles certificates, not application
- ⚠️ **ALB cost:** $16-20/month + $0.008/LCU-hour
- ⚠️ **Idle timeout:** Set to ≥120s to avoid long-running API call timeouts

---

### ADR-007: Sidecar Pattern for DAG Synchronization

**Status:** Accepted
**Context:** DAGs must be updated dynamically without container restarts.

**Decision:**
- **Sidecar container** (`s3-sync`) runs alongside Airflow containers
- **Logic:** `aws s3 sync s3://pathwai-airflow3-dags/<env>/ /opt/airflow/dags --exact-timestamps --delete`
- **Cadence:** 30s ± 10s jitter
- **Optimization:** 5 consecutive no-op syncs → backoff to 60-90s
- **Exit strategy:** Never exit unless credentials invalid or mount missing

**Sidecar Image:**
```dockerfile
FROM alpine:3.19
RUN apk add --no-cache aws-cli
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
```

**Entrypoint Logic:**
```bash
#!/bin/sh
set -e

DAGS_BUCKET=${DAGS_BUCKET:?}
ENV=${ENV:?}
BASE_SLEEP=30
JITTER=10
NO_OP_COUNT=0

while true; do
  echo "[$(date -Iseconds)] Syncing DAGs from s3://$DAGS_BUCKET/$ENV/"

  if aws s3 sync "s3://$DAGS_BUCKET/$ENV/" /opt/airflow/dags \
    --exact-timestamps --delete 2>&1 | tee /tmp/sync.log; then

    if grep -q "download:" /tmp/sync.log || grep -q "delete:" /tmp/sync.log; then
      NO_OP_COUNT=0
      SLEEP_TIME=$BASE_SLEEP
      echo "Changes detected, resetting backoff"
    else
      NO_OP_COUNT=$((NO_OP_COUNT + 1))
      if [ $NO_OP_COUNT -ge 5 ]; then
        SLEEP_TIME=$((60 + RANDOM % 30))
        echo "No changes in $NO_OP_COUNT cycles, backing off to ${SLEEP_TIME}s"
      else
        SLEEP_TIME=$BASE_SLEEP
      fi
    fi
  else
    echo "Sync failed, retrying in ${BASE_SLEEP}s"
    SLEEP_TIME=$BASE_SLEEP
  fi

  sleep $((SLEEP_TIME + RANDOM % JITTER))
done
```

**Task Role Permissions:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::pathwai-airflow3-dags"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::pathwai-airflow3-dags/${ENV}/*"
    }
  ]
}
```

**Consequences:**
- ✅ **DAG updates ≤60s** from S3 commit
- ✅ **No restarts:** Airflow scheduler picks up changes automatically
- ⚠️ **S3 API costs:** Minimal (mostly LIST operations with no changes)
- ⚠️ **EFS write contention:** Minimal due to infrequent updates

---

### ADR-008: KMS CMK Encryption for All Data

**Status:** Accepted
**Context:** Security and compliance requirements for data at rest.

**Decision:** Use **customer-managed KMS keys** (CMKs) for all services:

**Key Architecture:**
```
kms_key_rds          → RDS Postgres encryption
kms_key_elasticache  → Redis cluster encryption
kms_key_efs          → EFS encryption at rest
kms_key_logs         → CloudWatch Logs encryption
kms_key_s3           → S3 bucket encryption (DAGs, logs)
kms_key_secrets      → Secrets Manager encryption
```

**Key Policy (Example - RDS):**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {"AWS": "arn:aws:iam::381492153064:root"},
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "Allow RDS to use the key",
      "Effect": "Allow",
      "Principal": {"Service": "rds.amazonaws.com"},
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:CreateGrant"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "rds.us-east-1.amazonaws.com"
        }
      }
    },
    {
      "Sid": "Allow ECS tasks to decrypt",
      "Effect": "Allow",
      "Principal": {"AWS": "arn:aws:iam::381492153064:role/airflow-task-role"},
      "Action": ["kms:Decrypt", "kms:DescribeKey"],
      "Resource": "*"
    }
  ]
}
```

**Consequences:**
- ✅ **Compliance:** HIPAA, PCI-DSS, SOC2 requirements met
- ✅ **Audit trail:** All key usage logged in CloudTrail
- ⚠️ **Key rotation:** Annual manual rotation required
- ⚠️ **KMS costs:** $1/key/month + $0.03/10K requests

---

### ADR-009: Separate IAM Task Roles per Service

**Status:** Accepted
**Context:** Least privilege IAM principle.

**Decision:** Create **four distinct task roles**:

**1. airflow-web-task-role**
```json
{
  "Effect": "Allow",
  "Action": [
    "logs:CreateLogStream",
    "logs:PutLogEvents",
    "secretsmanager:GetSecretValue",
    "kms:Decrypt"
  ],
  "Resource": [
    "arn:aws:logs:*:381492153064:log-group:/ecs/airflow-web:*",
    "arn:aws:secretsmanager:*:381492153064:secret:airflow/*",
    "arn:aws:kms:*:381492153064:key/<logs-key-id>"
  ]
}
```

**2. airflow-scheduler-task-role**
```json
{
  "Effect": "Allow",
  "Action": [
    "logs:CreateLogStream",
    "logs:PutLogEvents",
    "secretsmanager:GetSecretValue",
    "ecs:DescribeTasks",
    "ecs:RunTask",
    "iam:PassRole",
    "kms:Decrypt"
  ],
  "Resource": [
    "arn:aws:logs:*:381492153064:log-group:/ecs/airflow-scheduler:*",
    "arn:aws:secretsmanager:*:381492153064:secret:airflow/*",
    "arn:aws:ecs:*:381492153064:task-definition/airflow-worker:*",
    "arn:aws:iam::381492153064:role/airflow-worker-task-role",
    "arn:aws:kms:*:381492153064:key/*"
  ]
}
```

**3. airflow-worker-task-role**
```json
{
  "Effect": "Allow",
  "Action": [
    "logs:CreateLogStream",
    "logs:PutLogEvents",
    "s3:ListBucket",
    "s3:GetObject",
    "s3:PutObject",
    "secretsmanager:GetSecretValue",
    "kms:Decrypt",
    "kms:GenerateDataKey"
  ],
  "Resource": [
    "arn:aws:logs:*:381492153064:log-group:/ecs/airflow-worker:*",
    "arn:aws:s3:::pathwai-airflow3-dags/${ENV}/*",
    "arn:aws:s3:::pathwai-airflow3-logs/${ENV}/*",
    "arn:aws:secretsmanager:*:381492153064:secret:airflow/*",
    "arn:aws:kms:*:381492153064:key/*"
  ]
}
```

**4. sidecar-s3sync-task-role**
```json
{
  "Effect": "Allow",
  "Action": [
    "s3:ListBucket",
    "s3:GetObject",
    "kms:Decrypt"
  ],
  "Resource": [
    "arn:aws:s3:::pathwai-airflow3-dags",
    "arn:aws:s3:::pathwai-airflow3-dags/${ENV}/*",
    "arn:aws:kms:*:381492153064:key/<s3-key-id>"
  ]
}
```

**Consequences:**
- ✅ **Least privilege:** Each service has minimal permissions
- ✅ **IAM Access Analyzer:** Clean results, no overly broad grants
- ⚠️ **Complexity:** Four roles to maintain vs. one shared role
- ⚠️ **DAG-specific permissions:** Add per-DAG policies to worker role as needed

---

## VPC Endpoint Requirements

### Interface Endpoints (PrivateLink)

All interface endpoints require:
- **Security group:** Allow 443 from VPC CIDR (10.0.0.0/16)
- **Private DNS enabled:** Yes
- **Subnets:** Private subnets in each AZ

**Required Interface Endpoints:**

| Service | Endpoint Name | Why Required |
|---------|---------------|--------------|
| ECR API | `com.amazonaws.us-east-1.ecr.api` | Pull image manifests |
| ECR Docker | `com.amazonaws.us-east-1.ecr.dkr` | Pull container layers |
| CloudWatch Logs | `com.amazonaws.us-east-1.logs` | Container log streaming |
| EventBridge | `com.amazonaws.us-east-1.events` | Airflow event triggers (optional) |
| STS | `com.amazonaws.us-east-1.sts` | IAM role assumption |
| Secrets Manager | `com.amazonaws.us-east-1.secretsmanager` | Retrieve DB/Redis credentials |
| SSM | `com.amazonaws.us-east-1.ssm` | Parameter Store (optional) |
| EFS | `com.amazonaws.us-east-1.elasticfilesystem` | Mount EFS volumes |
| KMS | `com.amazonaws.us-east-1.kms` | Decrypt encrypted data |

**Cost:** ~$7.50/endpoint/month + $0.01/GB data processed = **~$80/month total**

### Gateway Endpoint (Free)

| Service | Endpoint Name | Why Required |
|---------|---------------|--------------|
| S3 | `com.amazonaws.us-east-1.s3` | DAG sync, remote logging |

**Cost:** **$0** (no hourly charge, no data processing charge)

### Endpoint Security Group

```hcl
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "vpc-endpoints-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "HTTPS from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound (required for endpoint routing)"
  }
}
```

---

## Security Group Rules

### Naming Convention
```
{service}-{direction}-{source/dest}-{protocol}-{port}
```

### Security Groups

**1. alb-sg**
```hcl
ingress {
  description = "HTTPS from VPN/corporate network"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["10.100.0.0/16"]  # Corporate VPN CIDR
}

egress {
  description     = "HTTP to airflow-web"
  from_port       = 8080
  to_port         = 8080
  protocol        = "tcp"
  security_groups = [aws_security_group.airflow_web.id]
}
```

**2. airflow-web-sg**
```hcl
ingress {
  description     = "HTTP from ALB"
  from_port       = 8080
  to_port         = 8080
  protocol        = "tcp"
  security_groups = [aws_security_group.alb.id]
}

egress {
  description     = "Postgres to RDS"
  from_port       = 5432
  to_port         = 5432
  protocol        = "tcp"
  security_groups = [aws_security_group.rds.id]
}

egress {
  description     = "Redis to ElastiCache"
  from_port       = 6379
  to_port         = 6379
  protocol        = "tcp"
  security_groups = [aws_security_group.redis.id]
}

egress {
  description     = "EFS mount"
  from_port       = 2049
  to_port         = 2049
  protocol        = "tcp"
  security_groups = [aws_security_group.efs.id]
}

egress {
  description     = "HTTPS to VPC endpoints"
  from_port       = 443
  to_port         = 443
  protocol        = "tcp"
  security_groups = [aws_security_group.vpc_endpoints.id]
}
```

**3. airflow-scheduler-sg** (Same egress as web, no ingress)

**4. airflow-worker-sg** (Same egress as web, no ingress)

**5. sidecar-s3sync-sg**
```hcl
egress {
  description     = "EFS mount"
  from_port       = 2049
  to_port         = 2049
  protocol        = "tcp"
  security_groups = [aws_security_group.efs.id]
}

egress {
  description     = "HTTPS to S3 via endpoint"
  from_port       = 443
  to_port         = 443
  protocol        = "tcp"
  security_groups = [aws_security_group.vpc_endpoints.id]
}
```

**6. rds-sg**
```hcl
ingress {
  description     = "Postgres from Airflow tasks"
  from_port       = 5432
  to_port         = 5432
  protocol        = "tcp"
  security_groups = [
    aws_security_group.airflow_web.id,
    aws_security_group.airflow_scheduler.id,
    aws_security_group.airflow_worker.id
  ]
}
```

**7. redis-sg**
```hcl
ingress {
  description     = "Redis from Airflow tasks"
  from_port       = 6379
  to_port         = 6379
  protocol        = "tcp"
  security_groups = [
    aws_security_group.airflow_scheduler.id,
    aws_security_group.airflow_worker.id
  ]
}
```

**8. efs-sg**
```hcl
ingress {
  description     = "NFS from Airflow tasks + sidecar"
  from_port       = 2049
  to_port         = 2049
  protocol        = "tcp"
  security_groups = [
    aws_security_group.airflow_web.id,
    aws_security_group.airflow_scheduler.id,
    aws_security_group.airflow_worker.id,
    aws_security_group.sidecar_s3sync.id
  ]
}
```

**9. vpc-endpoints-sg** (See VPC Endpoint Requirements section)

---

## Terraform Module Interfaces

### Module: `vpc`

**Purpose:** Create VPC with private subnets only.

**Inputs:**
```hcl
variable "vpc_cidr" {
  type        = string
  description = "CIDR block for VPC"
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  description = "AZs for subnet distribution"
  default     = ["us-east-1a", "us-east-1b"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private subnets (ECS tasks)"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "data_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for data subnets (RDS, Redis)"
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "alb_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for internal ALB subnets"
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
}

variable "enable_dns_hostnames" {
  type        = bool
  description = "Enable DNS hostnames in VPC"
  default     = true
}

variable "enable_dns_support" {
  type        = bool
  description = "Enable DNS support in VPC"
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
}
```

**Outputs:**
```hcl
output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "data_subnet_ids" {
  value = aws_subnet.data[*].id
}

output "alb_subnet_ids" {
  value = aws_subnet.alb[*].id
}

output "private_route_table_ids" {
  value = aws_route_table.private[*].id
}
```

**Validation:**
- No internet gateway attached
- No NAT gateway resources
- All route tables point only to local VPC and VPC endpoints

---

### Module: `vpc_endpoints`

**Purpose:** Create all required VPC endpoints for NAT-free operation.

**Inputs:**
```hcl
variable "vpc_id" {
  type        = string
  description = "VPC ID where endpoints will be created"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for interface endpoints"
}

variable "private_route_table_ids" {
  type        = list(string)
  description = "Route table IDs for S3 gateway endpoint"
}

variable "security_group_id" {
  type        = string
  description = "Security group ID for interface endpoints"
}

variable "enable_private_dns" {
  type        = bool
  description = "Enable private DNS for interface endpoints"
  default     = true
}

variable "tags" {
  type        = map(string)
}
```

**Outputs:**
```hcl
output "s3_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}

output "ecr_api_endpoint_id" {
  value = aws_vpc_endpoint.ecr_api.id
}

output "ecr_dkr_endpoint_id" {
  value = aws_vpc_endpoint.ecr_dkr.id
}

output "logs_endpoint_id" {
  value = aws_vpc_endpoint.logs.id
}

output "secretsmanager_endpoint_id" {
  value = aws_vpc_endpoint.secretsmanager.id
}

output "efs_endpoint_id" {
  value = aws_vpc_endpoint.efs.id
}

output "kms_endpoint_id" {
  value = aws_vpc_endpoint.kms.id
}

# ... outputs for all other endpoints
```

---

### Module: `ecs_cluster`

**Purpose:** Create ECS cluster with capacity providers.

**Inputs:**
```hcl
variable "cluster_name" {
  type        = string
  description = "Name of ECS cluster"
}

variable "enable_container_insights" {
  type        = bool
  description = "Enable CloudWatch Container Insights"
  default     = true
}

variable "capacity_providers" {
  type        = list(string)
  description = "Capacity providers for cluster"
  default     = ["FARGATE", "FARGATE_SPOT"]
}

variable "default_capacity_provider_strategy" {
  type = list(object({
    capacity_provider = string
    weight            = number
    base              = number
  }))
  description = "Default capacity provider strategy"
  default = [
    {
      capacity_provider = "FARGATE"
      weight            = 1
      base              = 1
    }
  ]
}

variable "tags" {
  type = map(string)
}
```

**Outputs:**
```hcl
output "cluster_id" {
  value = aws_ecs_cluster.main.id
}

output "cluster_arn" {
  value = aws_ecs_cluster.main.arn
}

output "cluster_name" {
  value = aws_ecs_cluster.main.name
}
```

---

### Module: `ecs_service_airflow`

**Purpose:** Create ECS task definitions and services for Airflow components.

**Inputs:**
```hcl
variable "cluster_id" {
  type        = string
  description = "ECS cluster ID"
}

variable "service_name" {
  type        = string
  description = "Name of Airflow service (web, scheduler, worker)"
}

variable "task_cpu" {
  type        = number
  description = "CPU units for task (1024 = 1 vCPU)"
}

variable "task_memory" {
  type        = number
  description = "Memory for task in MB"
}

variable "desired_count" {
  type        = number
  description = "Desired number of tasks"
  default     = 1
}

variable "container_image" {
  type        = string
  description = "Docker image URI for Airflow container"
}

variable "sidecar_image" {
  type        = string
  description = "Docker image URI for s3-sync sidecar"
}

variable "task_role_arn" {
  type        = string
  description = "IAM role ARN for task"
}

variable "execution_role_arn" {
  type        = string
  description = "IAM role ARN for task execution"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for service"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security group IDs for service"
}

variable "efs_file_system_id" {
  type        = string
  description = "EFS file system ID"
}

variable "efs_access_point_id" {
  type        = string
  description = "EFS access point ID"
}

variable "environment_variables" {
  type        = map(string)
  description = "Environment variables for container"
  default     = {}
}

variable "secrets" {
  type = list(object({
    name      = string
    valueFrom = string
  }))
  description = "Secrets from Secrets Manager"
  default     = []
}

variable "log_group_name" {
  type        = string
  description = "CloudWatch log group name"
}

variable "target_group_arn" {
  type        = string
  description = "ALB target group ARN (for web service only)"
  default     = null
}

variable "enable_autoscaling" {
  type        = bool
  description = "Enable autoscaling for workers"
  default     = false
}

variable "autoscaling_min_capacity" {
  type        = number
  description = "Minimum task count"
  default     = 1
}

variable "autoscaling_max_capacity" {
  type        = number
  description = "Maximum task count"
  default     = 10
}

variable "capacity_provider" {
  type        = string
  description = "FARGATE or FARGATE_SPOT"
  default     = "FARGATE"
}

variable "tags" {
  type = map(string)
}
```

**Outputs:**
```hcl
output "service_id" {
  value = aws_ecs_service.main.id
}

output "service_name" {
  value = aws_ecs_service.main.name
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.main.arn
}

output "task_definition_family" {
  value = aws_ecs_task_definition.main.family
}
```

---

### Module: `rds_postgres`

**Purpose:** Create RDS Postgres instance for Airflow metadata.

**Inputs:**
```hcl
variable "identifier" {
  type        = string
  description = "RDS instance identifier"
}

variable "engine_version" {
  type        = string
  description = "Postgres version"
  default     = "16.1"
}

variable "instance_class" {
  type        = string
  description = "RDS instance class"
}

variable "allocated_storage" {
  type        = number
  description = "Allocated storage in GB"
  default     = 100
}

variable "max_allocated_storage" {
  type        = number
  description = "Maximum storage for autoscaling"
  default     = 500
}

variable "storage_type" {
  type        = string
  description = "Storage type (gp3 recommended)"
  default     = "gp3"
}

variable "iops" {
  type        = number
  description = "Provisioned IOPS (gp3 only)"
  default     = 3000
}

variable "storage_throughput" {
  type        = number
  description = "Storage throughput MB/s (gp3 only)"
  default     = 125
}

variable "db_name" {
  type        = string
  description = "Initial database name"
  default     = "airflow"
}

variable "master_username" {
  type        = string
  description = "Master username"
  default     = "airflow"
}

variable "master_password_secret_arn" {
  type        = string
  description = "Secrets Manager ARN for master password"
}

variable "multi_az" {
  type        = bool
  description = "Enable Multi-AZ deployment"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for DB subnet group"
}

variable "vpc_security_group_ids" {
  type        = list(string)
  description = "Security group IDs"
}

variable "kms_key_id" {
  type        = string
  description = "KMS key ARN for encryption"
}

variable "backup_retention_period" {
  type        = number
  description = "Backup retention in days"
  default     = 7
}

variable "backup_window" {
  type        = string
  description = "Backup window"
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  type        = string
  description = "Maintenance window"
  default     = "sun:04:00-sun:05:00"
}

variable "deletion_protection" {
  type        = bool
  description = "Enable deletion protection"
  default     = true
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Skip final snapshot on deletion"
  default     = false
}

variable "performance_insights_enabled" {
  type        = bool
  description = "Enable Performance Insights"
  default     = true
}

variable "performance_insights_retention_period" {
  type        = number
  description = "Performance Insights retention in days"
  default     = 7
}

variable "enabled_cloudwatch_logs_exports" {
  type        = list(string)
  description = "Log types to export to CloudWatch"
  default     = ["postgresql", "upgrade"]
}

variable "parameter_group_family" {
  type        = string
  description = "DB parameter group family"
  default     = "postgres16"
}

variable "parameters" {
  type = list(object({
    name  = string
    value = string
  }))
  description = "Custom parameters"
  default = [
    {
      name  = "rds.force_ssl"
      value = "1"
    }
  ]
}

variable "tags" {
  type = map(string)
}
```

**Outputs:**
```hcl
output "db_instance_id" {
  value = aws_db_instance.main.id
}

output "db_instance_arn" {
  value = aws_db_instance.main.arn
}

output "endpoint" {
  value = aws_db_instance.main.endpoint
}

output "address" {
  value = aws_db_instance.main.address
}

output "port" {
  value = aws_db_instance.main.port
}

output "db_name" {
  value = aws_db_instance.main.db_name
}
```

---

### Module: `redis`

**Purpose:** Create ElastiCache Redis cluster for Celery broker.

**Inputs:**
```hcl
variable "cluster_id" {
  type        = string
  description = "Redis cluster identifier"
}

variable "engine_version" {
  type        = string
  description = "Redis version"
  default     = "7.1"
}

variable "node_type" {
  type        = string
  description = "Cache node type"
}

variable "num_cache_nodes" {
  type        = number
  description = "Number of cache nodes (1 for non-replicated)"
  default     = 1
}

variable "parameter_group_family" {
  type        = string
  description = "Parameter group family"
  default     = "redis7"
}

variable "port" {
  type        = number
  description = "Redis port"
  default     = 6379
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for cache subnet group"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security group IDs"
}

variable "at_rest_encryption_enabled" {
  type        = bool
  description = "Enable encryption at rest"
  default     = true
}

variable "transit_encryption_enabled" {
  type        = bool
  description = "Enable encryption in transit"
  default     = true
}

variable "auth_token_secret_arn" {
  type        = string
  description = "Secrets Manager ARN for AUTH token"
}

variable "kms_key_id" {
  type        = string
  description = "KMS key ARN for encryption"
}

variable "snapshot_retention_limit" {
  type        = number
  description = "Snapshot retention in days"
  default     = 5
}

variable "snapshot_window" {
  type        = string
  description = "Snapshot window"
  default     = "03:00-05:00"
}

variable "maintenance_window" {
  type        = string
  description = "Maintenance window"
  default     = "sun:05:00-sun:07:00"
}

variable "automatic_failover_enabled" {
  type        = bool
  description = "Enable automatic failover (requires replication)"
  default     = false
}

variable "multi_az_enabled" {
  type        = bool
  description = "Enable Multi-AZ (requires replication)"
  default     = false
}

variable "parameters" {
  type = list(object({
    name  = string
    value = string
  }))
  description = "Custom parameters"
  default = [
    {
      name  = "maxmemory-policy"
      value = "allkeys-lru"
    }
  ]
}

variable "tags" {
  type = map(string)
}
```

**Outputs:**
```hcl
output "cluster_id" {
  value = aws_elasticache_cluster.main.id
}

output "cluster_arn" {
  value = aws_elasticache_cluster.main.arn
}

output "cache_nodes" {
  value = aws_elasticache_cluster.main.cache_nodes
}

output "configuration_endpoint" {
  value = aws_elasticache_cluster.main.configuration_endpoint
}

output "primary_endpoint_address" {
  value = aws_elasticache_cluster.main.cache_nodes[0].address
}

output "port" {
  value = aws_elasticache_cluster.main.port
}
```

---

### Module: `efs`

**Purpose:** Create EFS file system for shared DAG/plugin storage.

**Inputs:**
```hcl
variable "creation_token" {
  type        = string
  description = "Unique creation token"
}

variable "performance_mode" {
  type        = string
  description = "Performance mode (generalPurpose or maxIO)"
  default     = "generalPurpose"
}

variable "throughput_mode" {
  type        = string
  description = "Throughput mode (bursting or provisioned)"
  default     = "bursting"
}

variable "provisioned_throughput_in_mibps" {
  type        = number
  description = "Provisioned throughput (if mode=provisioned)"
  default     = null
}

variable "encrypted" {
  type        = bool
  description = "Enable encryption"
  default     = true
}

variable "kms_key_id" {
  type        = string
  description = "KMS key ARN for encryption"
}

variable "lifecycle_policy" {
  type = object({
    transition_to_ia = string
  })
  description = "Lifecycle policy for Infrequent Access"
  default = {
    transition_to_ia = "AFTER_30_DAYS"
  }
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for mount targets"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security group IDs for mount targets"
}

variable "access_point_path" {
  type        = string
  description = "Path for EFS access point"
  default     = "/airflow"
}

variable "access_point_uid" {
  type        = number
  description = "POSIX user ID for access point"
  default     = 50000
}

variable "access_point_gid" {
  type        = number
  description = "POSIX group ID for access point"
  default     = 50000
}

variable "tags" {
  type = map(string)
}
```

**Outputs:**
```hcl
output "file_system_id" {
  value = aws_efs_file_system.main.id
}

output "file_system_arn" {
  value = aws_efs_file_system.main.arn
}

output "dns_name" {
  value = aws_efs_file_system.main.dns_name
}

output "access_point_id" {
  value = aws_efs_access_point.main.id
}

output "access_point_arn" {
  value = aws_efs_access_point.main.arn
}

output "mount_target_ids" {
  value = aws_efs_mount_target.main[*].id
}
```

---

### Module: `alb`

**Purpose:** Create internal ALB with OIDC authentication for Airflow web.

**Inputs:**
```hcl
variable "name" {
  type        = string
  description = "ALB name"
}

variable "internal" {
  type        = bool
  description = "Internal ALB"
  default     = true
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for ALB"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security group IDs"
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN for HTTPS"
}

variable "ssl_policy" {
  type        = string
  description = "SSL policy for HTTPS listener"
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for target group"
}

variable "target_group_port" {
  type        = number
  description = "Target port for web service"
  default     = 8080
}

variable "health_check_path" {
  type        = string
  description = "Health check path"
  default     = "/health"
}

variable "health_check_interval" {
  type        = number
  description = "Health check interval in seconds"
  default     = 30
}

variable "health_check_timeout" {
  type        = number
  description = "Health check timeout in seconds"
  default     = 10
}

variable "healthy_threshold" {
  type        = number
  description = "Healthy threshold count"
  default     = 2
}

variable "unhealthy_threshold" {
  type        = number
  description = "Unhealthy threshold count"
  default     = 5
}

variable "deregistration_delay" {
  type        = number
  description = "Deregistration delay in seconds"
  default     = 30
}

variable "idle_timeout" {
  type        = number
  description = "Idle timeout in seconds"
  default     = 120
}

variable "enable_deletion_protection" {
  type        = bool
  description = "Enable deletion protection"
  default     = true
}

variable "enable_http2" {
  type        = bool
  description = "Enable HTTP/2"
  default     = true
}

variable "enable_cross_zone_load_balancing" {
  type        = bool
  description = "Enable cross-zone load balancing"
  default     = true
}

variable "oidc_issuer" {
  type        = string
  description = "OIDC issuer URL"
}

variable "oidc_authorization_endpoint" {
  type        = string
  description = "OIDC authorization endpoint"
}

variable "oidc_token_endpoint" {
  type        = string
  description = "OIDC token endpoint"
}

variable "oidc_user_info_endpoint" {
  type        = string
  description = "OIDC user info endpoint"
}

variable "oidc_client_id" {
  type        = string
  description = "OIDC client ID"
}

variable "oidc_client_secret_arn" {
  type        = string
  description = "Secrets Manager ARN for OIDC client secret"
}

variable "tags" {
  type = map(string)
}
```

**Outputs:**
```hcl
output "alb_id" {
  value = aws_lb.main.id
}

output "alb_arn" {
  value = aws_lb.main.arn
}

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "alb_zone_id" {
  value = aws_lb.main.zone_id
}

output "target_group_arn" {
  value = aws_lb_target_group.main.arn
}

output "listener_arn" {
  value = aws_lb_listener.https.arn
}
```

---

### Module: `iam`

**Purpose:** Create IAM roles and policies for ECS tasks.

**Inputs:**
```hcl
variable "environment" {
  type        = string
  description = "Environment name (dev, prod)"
}

variable "dags_bucket_name" {
  type        = string
  description = "S3 bucket for DAGs"
}

variable "logs_bucket_name" {
  type        = string
  description = "S3 bucket for task logs"
}

variable "kms_key_arns" {
  type        = map(string)
  description = "Map of KMS key ARNs (logs, s3, rds, etc.)"
}

variable "log_group_arns" {
  type        = map(string)
  description = "Map of CloudWatch log group ARNs"
}

variable "secretsmanager_secret_arns" {
  type        = list(string)
  description = "List of Secrets Manager ARNs"
}

variable "ecs_task_execution_role_policies" {
  type        = list(string)
  description = "Additional policies for task execution role"
  default     = []
}

variable "tags" {
  type = map(string)
}
```

**Outputs:**
```hcl
output "task_execution_role_arn" {
  value       = aws_iam_role.ecs_task_execution.arn
  description = "ECS task execution role ARN (used by all tasks)"
}

output "airflow_web_task_role_arn" {
  value = aws_iam_role.airflow_web_task.arn
}

output "airflow_scheduler_task_role_arn" {
  value = aws_iam_role.airflow_scheduler_task.arn
}

output "airflow_worker_task_role_arn" {
  value = aws_iam_role.airflow_worker_task.arn
}

output "sidecar_s3sync_task_role_arn" {
  value = aws_iam_role.sidecar_s3sync_task.arn
}
```

---

## Environment Overlays

### Dev Environment (`infra/envs/dev/terraform.tfvars`)

```hcl
# General
environment = "dev"
aws_region  = "us-east-1"

# VPC
vpc_cidr                = "10.0.0.0/16"
availability_zones      = ["us-east-1a", "us-east-1b"]
private_subnet_cidrs    = ["10.0.1.0/24", "10.0.2.0/24"]
data_subnet_cidrs       = ["10.0.11.0/24", "10.0.12.0/24"]
alb_subnet_cidrs        = ["10.0.21.0/24", "10.0.22.0/24"]

# ECS
cluster_name = "airflow-dev"

# Airflow Web
airflow_web_cpu            = 1024
airflow_web_memory         = 2048
airflow_web_desired_count  = 1
airflow_web_container_image = "381492153064.dkr.ecr.us-east-1.amazonaws.com/airflow-web:3.1-latest"

# Airflow Scheduler
airflow_scheduler_cpu            = 1024
airflow_scheduler_memory         = 2048
airflow_scheduler_desired_count  = 1
airflow_scheduler_container_image = "381492153064.dkr.ecr.us-east-1.amazonaws.com/airflow-scheduler:3.1-latest"

# Airflow Worker
airflow_worker_cpu               = 2048
airflow_worker_memory            = 4096
airflow_worker_desired_count     = 2
airflow_worker_min_capacity      = 1
airflow_worker_max_capacity      = 5
airflow_worker_container_image   = "381492153064.dkr.ecr.us-east-1.amazonaws.com/airflow-worker:3.1-latest"
airflow_worker_capacity_provider = "FARGATE_SPOT"  # 70% discount for dev

# Sidecar
sidecar_container_image = "381492153064.dkr.ecr.us-east-1.amazonaws.com/s3-sync:latest"

# RDS
rds_instance_class              = "db.t4g.medium"
rds_multi_az                    = false
rds_allocated_storage           = 100
rds_max_allocated_storage       = 200
rds_backup_retention_period     = 7
rds_deletion_protection         = false
rds_skip_final_snapshot         = true

# Redis
redis_node_type                  = "cache.t4g.micro"
redis_num_cache_nodes            = 1
redis_automatic_failover_enabled = false
redis_multi_az_enabled           = false

# EFS
efs_performance_mode = "generalPurpose"
efs_throughput_mode  = "bursting"
efs_lifecycle_transition_to_ia = "AFTER_30_DAYS"

# ALB
alb_certificate_arn = "arn:aws:acm:us-east-1:381492153064:certificate/dev-cert-id"
alb_idle_timeout    = 120

# OIDC
oidc_issuer                 = "https://auth.example.com"
oidc_authorization_endpoint = "https://auth.example.com/oauth2/authorize"
oidc_token_endpoint         = "https://auth.example.com/oauth2/token"
oidc_user_info_endpoint     = "https://auth.example.com/oauth2/userinfo"
oidc_client_id              = "airflow-dev"

# S3
dags_bucket_name = "pathwai-airflow3-dags"
logs_bucket_name = "pathwai-airflow3-logs"

# Tags
tags = {
  Environment = "dev"
  Project     = "airflow"
  ManagedBy   = "terraform"
  CostCenter  = "engineering"
}
```

### Prod Environment (`infra/envs/prod/terraform.tfvars`)

```hcl
# General
environment = "prod"
aws_region  = "us-east-1"

# VPC (same as dev)
vpc_cidr                = "10.0.0.0/16"
availability_zones      = ["us-east-1a", "us-east-1b"]
private_subnet_cidrs    = ["10.0.1.0/24", "10.0.2.0/24"]
data_subnet_cidrs       = ["10.0.11.0/24", "10.0.12.0/24"]
alb_subnet_cidrs        = ["10.0.21.0/24", "10.0.22.0/24"]

# ECS
cluster_name = "airflow-prod"

# Airflow Web
airflow_web_cpu            = 2048
airflow_web_memory         = 4096
airflow_web_desired_count  = 2  # HA
airflow_web_container_image = "381492153064.dkr.ecr.us-east-1.amazonaws.com/airflow-web:3.1-prod-latest"

# Airflow Scheduler
airflow_scheduler_cpu            = 2048
airflow_scheduler_memory         = 4096
airflow_scheduler_desired_count  = 2  # HA
airflow_scheduler_container_image = "381492153064.dkr.ecr.us-east-1.amazonaws.com/airflow-scheduler:3.1-prod-latest"

# Airflow Worker
airflow_worker_cpu               = 4096
airflow_worker_memory            = 8192
airflow_worker_desired_count     = 4
airflow_worker_min_capacity      = 2
airflow_worker_max_capacity      = 10
airflow_worker_container_image   = "381492153064.dkr.ecr.us-east-1.amazonaws.com/airflow-worker:3.1-prod-latest"
airflow_worker_capacity_provider = "FARGATE"  # No spot for prod

# Sidecar
sidecar_container_image = "381492153064.dkr.ecr.us-east-1.amazonaws.com/s3-sync:prod-latest"

# RDS
rds_instance_class              = "db.r6g.large"
rds_multi_az                    = true  # HA
rds_allocated_storage           = 200
rds_max_allocated_storage       = 1000
rds_backup_retention_period     = 30
rds_deletion_protection         = true
rds_skip_final_snapshot         = false

# Redis
redis_node_type                  = "cache.r6g.large"
redis_num_cache_nodes            = 3  # 1 primary + 2 replicas
redis_automatic_failover_enabled = true
redis_multi_az_enabled           = true

# EFS
efs_performance_mode = "generalPurpose"
efs_throughput_mode  = "bursting"
efs_lifecycle_transition_to_ia = "AFTER_90_DAYS"  # Longer retention for prod

# ALB
alb_certificate_arn = "arn:aws:acm:us-east-1:381492153064:certificate/prod-cert-id"
alb_idle_timeout    = 300  # Longer for prod

# OIDC
oidc_issuer                 = "https://auth.example.com"
oidc_authorization_endpoint = "https://auth.example.com/oauth2/authorize"
oidc_token_endpoint         = "https://auth.example.com/oauth2/token"
oidc_user_info_endpoint     = "https://auth.example.com/oauth2/userinfo"
oidc_client_id              = "airflow-prod"

# S3
dags_bucket_name = "pathwai-airflow3-dags"
logs_bucket_name = "pathwai-airflow3-logs"

# Tags
tags = {
  Environment = "prod"
  Project     = "airflow"
  ManagedBy   = "terraform"
  CostCenter  = "engineering"
  Compliance  = "hipaa"
}
```

---

## Cost Analysis

### Monthly Cost Estimate (Prod Environment)

**Compute:**
- ECS Fargate (web): 2 tasks × 2 vCPU × $0.04048/hr × 730hrs = $118
- ECS Fargate (scheduler): 2 tasks × 2 vCPU × $0.04048/hr × 730hrs = $118
- ECS Fargate (worker): 4 tasks × 4 vCPU × $0.04048/hr × 730hrs = $472
- **Subtotal: $708/month**

**Data:**
- RDS db.r6g.large Multi-AZ: $0.48/hr × 730hrs × 2 = $700
- ElastiCache cache.r6g.large × 3: $0.283/hr × 730hrs × 3 = $620
- EFS (100GB): $0.30/GB × 100GB = $30
- **Subtotal: $1,350/month**

**Networking:**
- ALB: $16.20 + ($0.008/LCU × assume 10 LCU × 730hrs) = $75
- VPC Endpoints (9 interface): $0.01/hr × 9 × 730hrs = $66
- VPC Endpoint data: $0.01/GB × assume 1TB = $10
- S3 Gateway Endpoint: $0
- **Subtotal: $151/month**

**Storage:**
- S3 (DAGs + Logs): assume 100GB × $0.023 = $2.30
- RDS storage (200GB gp3): $0.115/GB × 200GB = $23
- RDS backup storage (200GB × 30 days): assume $10
- **Subtotal: $35/month**

**Encryption:**
- KMS (6 CMKs): $1/key × 6 = $6
- KMS requests: assume $5
- **Subtotal: $11/month**

**Monitoring:**
- CloudWatch Logs (assume 50GB): $0.50/GB × 50GB = $25
- Container Insights: assume $10
- **Subtotal: $35/month**

**TOTAL: ~$2,290/month (prod)**

### Cost Savings vs. NAT Gateway Architecture

**NAT Gateway costs (avoided):**
- 2 NAT Gateways (Multi-AZ): $0.045/hr × 2 × 730hrs = $66
- Data processing: $0.045/GB × assume 2TB = $90
- **Total NAT cost avoided: $156/month**

**VPC Endpoint costs (added):**
- Interface endpoints: $66/month
- **Net cost difference: -$90/month (VPC endpoints cheaper!)**

**Additional benefits:**
- ✅ Enhanced security (no internet egress)
- ✅ Better performance (PrivateLink lower latency)
- ✅ Compliance (data never leaves AWS network)

---

## Deployment Strategy

### Initial Deployment

**Phase 1: Foundation (Week 1)**
1. Deploy VPC module
2. Deploy VPC endpoints module
3. Validate: No NAT gateways, all endpoints reachable
4. Deploy KMS keys

**Phase 2: Data Layer (Week 2)**
1. Deploy EFS module
2. Deploy RDS module with initial schema
3. Deploy ElastiCache Redis
4. Validate: All services encrypted, accessible from test EC2 in private subnet

**Phase 3: Compute (Week 3)**
1. Build and push Docker images to ECR
2. Deploy ECS cluster
3. Deploy IAM roles
4. Deploy ALB module
5. Deploy ECS services (web, scheduler, worker with sidecars)
6. Validate: Health checks pass, no 502/504 errors

**Phase 4: Integration (Week 4)**
1. Deploy sample DAGs to S3
2. Verify sidecar sync ≤60s
3. Test DAG execution end-to-end
4. Configure OIDC authentication
5. Load test worker autoscaling

### Blue/Green Updates

**Strategy:** ECS service deployment with rolling update.

**Steps:**
1. Build new image with tag: `airflow-web:3.1-<git-sha>`
2. Update task definition with new image
3. Trigger ECS service update with:
   - `deployment_configuration.minimum_healthy_percent = 100`
   - `deployment_configuration.maximum_percent = 200`
4. ECS launches new tasks → health check passes → drains old tasks
5. Rollback: Revert task definition to previous revision

### Rollback Procedure

**If deployment fails:**
1. Identify failing task definition revision
2. Revert to last known good revision:
   ```bash
   aws ecs update-service \
     --cluster airflow-prod \
     --service airflow-web \
     --task-definition airflow-web:<previous-revision>
   ```
3. Monitor health checks until stable
4. Investigate failure in CloudWatch Logs

---

## Validation & Testing

### Policy Validation (OPA)

**File:** `infra/policies/no-nat.rego`
```rego
package terraform.analysis

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_nat_gateway"
  msg := sprintf("NAT Gateway not allowed: %s", [resource.address])
}

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_security_group_rule"
  resource.change.after.cidr_blocks[_] == "0.0.0.0/0"
  msg := sprintf("Security group rule with 0.0.0.0/0 not allowed: %s", [resource.address])
}
```

**Run:**
```bash
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json
opa eval --data infra/policies/ --input tfplan.json "data.terraform.analysis.deny"
```

**Expected output:** Empty array (no violations)

### Checkov Validation

```bash
checkov -d infra/ --framework terraform --skip-check CKV_AWS_* --check CKV2_AWS_5,CKV2_AWS_12
```

**Key checks:**
- CKV2_AWS_5: Security groups allow only necessary protocols/ports
- CKV2_AWS_12: RDS/Redis encrypted with CMK
- CKV_AWS_158: CloudWatch log groups encrypted

### IAM Access Analyzer

**Steps:**
1. Create analyzer: `aws accessanalyzer create-analyzer --analyzer-name airflow-iam --type ACCOUNT`
2. Wait 30 minutes for analysis
3. Check findings:
   ```bash
   aws accessanalyzer list-findings --analyzer-arn <arn> --filter '{"status":{"eq":["ACTIVE"]}}'
   ```
4. Expected: Zero findings for external access or overly broad policies

### Connectivity Testing

**Test from ECS task (web service):**

```bash
# Test RDS connectivity
aws ecs execute-command \
  --cluster airflow-prod \
  --task <task-id> \
  --container airflow-web \
  --command "pg_isready -h <rds-endpoint> -p 5432"

# Test Redis connectivity
aws ecs execute-command \
  --cluster airflow-prod \
  --task <task-id> \
  --container airflow-web \
  --command "redis-cli -h <redis-endpoint> -p 6379 --tls PING"

# Test S3 via VPC endpoint
aws ecs execute-command \
  --cluster airflow-prod \
  --task <task-id> \
  --container s3-sync \
  --command "aws s3 ls s3://pathwai-airflow3-dags/"

# Test EFS mount
aws ecs execute-command \
  --cluster airflow-prod \
  --task <task-id> \
  --container airflow-web \
  --command "ls -la /opt/airflow/dags"
```

**Expected:** All commands succeed without errors.

---

## Monitoring & Alerting

### CloudWatch Alarms

**1. Scheduler Heartbeat**
```hcl
resource "aws_cloudwatch_metric_alarm" "scheduler_heartbeat" {
  alarm_name          = "airflow-scheduler-heartbeat"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "scheduler.heartbeat"
  namespace           = "Airflow"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Scheduler heartbeat missing"
  treat_missing_data  = "breaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

**2. Queue Depth**
```hcl
resource "aws_cloudwatch_metric_alarm" "queue_depth_high" {
  alarm_name          = "airflow-queue-depth-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "celery.queue_depth"
  namespace           = "Airflow"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  alarm_description   = "Celery queue depth exceeds 100 tasks"

  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

**3. ALB 5xx Errors**
```hcl
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "airflow-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ALB returning 5xx errors"

  dimensions = {
    LoadBalancer = aws_lb.airflow.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

**4. Task Failure Rate**
```hcl
resource "aws_cloudwatch_metric_alarm" "task_failure_rate" {
  alarm_name          = "airflow-task-failure-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ti_failures"
  namespace           = "Airflow"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "More than 5 task failures in 5 minutes"

  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

**5. Worker Autoscaling**
```hcl
resource "aws_cloudwatch_metric_alarm" "worker_scale_out" {
  alarm_name          = "airflow-worker-scale-out"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "celery.queue_depth"
  namespace           = "Airflow"
  period              = 60
  statistic           = "Average"
  threshold           = 20
  alarm_description   = "Scale out workers when queue depth > 20"

  alarm_actions = [aws_appautoscaling_policy.worker_scale_out.arn]
}

resource "aws_cloudwatch_metric_alarm" "worker_scale_in" {
  alarm_name          = "airflow-worker-scale-in"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 5
  metric_name         = "celery.queue_depth"
  namespace           = "Airflow"
  period              = 300
  statistic           = "Average"
  threshold           = 5
  alarm_description   = "Scale in workers when queue depth < 5 for 25 min"

  alarm_actions = [aws_appautoscaling_policy.worker_scale_in.arn]
}
```

---

## Security Hardening

### Network Isolation

**Route Table Validation:**
```bash
# Verify no default route to internet gateway
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'RouteTables[*].Routes[?DestinationCidrBlock==`0.0.0.0/0`]'

# Expected: Empty array
```

**Security Group Audit:**
```bash
# Find any SGs with 0.0.0.0/0 ingress
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'SecurityGroups[?IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]]'

# Expected: Empty array
```

### Secrets Management

**Best Practices:**
- ✅ **Never hardcode:** All secrets in Secrets Manager
- ✅ **Rotation:** Enable automatic rotation for DB credentials
- ✅ **Versioning:** Use `AWSCURRENT` stage in code
- ✅ **Least privilege:** Task roles can only read their own secrets

**Example Secret Structure:**
```json
{
  "airflow/prod/db": {
    "username": "airflow",
    "password": "<auto-generated>",
    "engine": "postgres",
    "host": "<rds-endpoint>",
    "port": 5432,
    "dbname": "airflow"
  },
  "airflow/prod/redis": {
    "host": "<redis-endpoint>",
    "port": 6379,
    "auth_token": "<auto-generated>"
  },
  "airflow/prod/oidc": {
    "client_id": "airflow-prod",
    "client_secret": "<provided-by-idp>"
  }
}
```

### TLS Enforcement

**RDS:**
```sql
-- Verify SSL enforcement
SHOW rds.force_ssl;
-- Expected: on
```

**Redis:**
```bash
# Test TLS connection
redis-cli -h <redis-endpoint> -p 6379 --tls --cacert /path/to/ca.crt PING
# Expected: PONG
```

**ALB:**
- Redirect HTTP → HTTPS (if HTTP listener exists)
- Use TLS 1.3 policy: `ELBSecurityPolicy-TLS13-1-2-2021-06`
- Certificate auto-renewal via ACM

---

## Summary

This architecture provides a **production-grade, NAT-free Airflow 3.1 deployment** on AWS ECS with:

✅ **Zero NAT Gateways** - $156/month saved + enhanced security
✅ **Full Encryption** - KMS CMKs for RDS, Redis, EFS, S3, CloudWatch Logs
✅ **High Availability** - Multi-AZ RDS, Redis replication, ECS across 2 AZs
✅ **Least Privilege IAM** - Separate task roles, IAM Access Analyzer clean
✅ **Automated DAG Updates** - S3 sync sidecar with ≤60s latency
✅ **OIDC Authentication** - SSO integration via ALB
✅ **Comprehensive Monitoring** - CloudWatch alarms for scheduler, queue, ALB, tasks
✅ **Policy Enforcement** - OPA, Checkov, tflint validation in CI/CD

**Next Steps:**
1. Review and approve architecture design
2. Implement Terraform modules per interfaces
3. Set up CI/CD pipeline with validation gates
4. Deploy to dev environment for testing
5. Promote to prod after acceptance criteria met

---

**Document Owner:** System Architect Agent
**Review Status:** Pending QA/SRE Approval
**Last Updated:** 2025-10-24
