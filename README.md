# Airflow 3.1 on AWS ECS/Fargate - NAT-Free Architecture

Production-grade Apache Airflow 3.1 deployment on AWS ECS Fargate with **zero NAT gateways**. Infrastructure uses private subnets only with VPC endpoints for all AWS service communication.

## 🎯 Goals

- **Deploy in <60 minutes**: Automated Terraform + CI/CD
- **NAT-Free**: Zero egress costs from NAT gateways
- **Production-Ready**: KMS encryption, least-privilege IAM, comprehensive monitoring
- **Day-2 Operations**: Boring and predictable

## 🏗️ Architecture

### Core Components
- **Compute**: ECS Fargate (Web, Scheduler, Workers)
- **Metadata DB**: RDS Postgres with KMS encryption
- **Broker**: ElastiCache Redis for Celery
- **Storage**: EFS for DAGs/plugins, S3 for remote logs
- **Networking**: Private subnets only + 9 VPC endpoints
- **Load Balancing**: Internal ALB with TLS

### Key Features
- ✅ **No NAT Gateways** - VPC endpoints for all AWS services
- ✅ **Auto DAG Sync** - S3 → EFS sidecar (≤60s latency)
- ✅ **Auto Scaling** - Workers scale 0-10 based on queue depth
- ✅ **KMS Encryption** - All data encrypted at rest
- ✅ **Least Privilege IAM** - Separate task roles per service
- ✅ **Comprehensive CI/CD** - Validation with tflint, checkov, OPA

## 📋 Prerequisites

- AWS Account: `381492153064`
- AWS CLI configured
- Terraform >= 1.12
- Docker for image builds
- ACM certificate for ALB HTTPS

## 🚀 Quick Start

### 1. Clone and Initialize

```bash
git clone <repo-url>
cd airflow-ecs
```

### 2. Create S3 Buckets

```bash
# Terraform state
aws s3 mb s3://pathwai-terraform-state --region us-east-1

# DAGs and logs
aws s3 mb s3://pathwai-airflow3-dags --region us-east-1
aws s3 mb s3://pathwai-airflow3-logs --region us-east-1
```

### 3. Store Secrets

```bash
aws secretsmanager create-secret \
  --name pathwai-airflow-dev/db-password \
  --secret-string "CHANGE_ME_SECURE_PASSWORD"
```

### 4. Update Terraform Variables

Edit `infra/envs/dev/terraform.tfvars`:
- Update `alb_certificate_arn` with your ACM certificate ARN
- Verify other settings match your requirements

### 5. Deploy Infrastructure

```bash
cd infra/envs/dev
terraform init
terraform plan
terraform apply
```

### 6. Build and Push Images

```bash
# ECR login
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  381492153064.dkr.ecr.us-east-1.amazonaws.com

# Build all images
cd app/docker
for dir in airflow-base airflow-web airflow-scheduler airflow-worker sidecar-s3sync; do
  docker build -t 381492153064.dkr.ecr.us-east-1.amazonaws.com/$dir:latest $dir/
  docker push 381492153064.dkr.ecr.us-east-1.amazonaws.com/$dir:latest
done
```

### 7. Initialize Airflow

See `docs/runbooks/operations.md` for detailed steps on:
- Database initialization
- Admin user creation
- First DAG deployment

## 📁 Repository Structure

```
airflow-ecs/
├── infra/
│   ├── modules/           # Terraform modules
│   │   ├── vpc/          # Private subnets only
│   │   ├── vpc_endpoints/ # S3, ECR, Logs, STS, etc.
│   │   ├── ecs_cluster/
│   │   ├── ecs_service_airflow/  # Web, scheduler, workers
│   │   ├── rds_postgres/
│   │   ├── redis/
│   │   ├── efs/
│   │   ├── alb/
│   │   └── iam/
│   ├── envs/
│   │   ├── dev/          # Dev environment
│   │   └── prod/         # Prod environment
│   └── policies/         # OPA security policies
├── app/
│   ├── docker/           # Docker configurations
│   │   ├── airflow-base/
│   │   ├── airflow-web/
│   │   ├── airflow-scheduler/
│   │   ├── airflow-worker/
│   │   └── sidecar-s3sync/  # S3 DAG sync
│   └── config/           # Airflow configurations
├── ci/
│   └── github-actions/   # CI/CD pipelines
│       ├── validate.yml  # NO-NAT check, tflint, checkov
│       ├── deploy.yml
│       └── dag-sync.yml
├── docs/
│   └── runbooks/
│       └── operations.md # Complete operations guide
├── dags/                 # Your Airflow DAGs
└── README.md
```

## 🔒 Security Features

### Network Security
- **Private Subnets Only**: No public subnets or NAT gateways
- **VPC Endpoints**: S3, ECR (api+dkr), Logs, Events, STS, Secrets Manager, SSM, EFS, KMS
- **Security Groups**: Least-privilege access, no 0.0.0.0/0 rules
- **Internal ALB**: TLS termination, supports SSO via OIDC

### Encryption
- **KMS CMKs**: RDS, Redis, EFS, CloudWatch Logs, S3
- **TLS Everywhere**: Redis, EFS, ALB
- **Secrets Manager**: Database passwords, API keys

### IAM
- **Task Roles**: Separate roles for web, scheduler, worker, sidecar
- **Least Privilege**: Scoped to specific S3 paths and resources
- **No Wildcards**: IAM Access Analyzer validation

## 📊 Monitoring & Alarms

### CloudWatch Metrics
- Scheduler heartbeat
- Worker queue depth and task duration
- ALB health and 5xx errors
- ECS desired vs running tasks
- RDS connections and performance

### Log Aggregation
- **Container Logs**: CloudWatch Logs
- **Task Logs**: S3 remote logging partitioned by date
- **Retention**: 7 days (dev), 30 days (prod)

## 🎛️ Operations

### Updating DAGs
```bash
# Upload to S3
aws s3 sync ./dags s3://pathwai-airflow3-dags/dev/ --delete

# Sidecar syncs to EFS within 60 seconds
# No container restarts needed
```

### Scaling Workers
Workers autoscale on CPU/memory. Manual scaling:
```bash
aws ecs update-service \
  --cluster pathwai-airflow-dev-cluster \
  --service pathwai-airflow-dev-worker \
  --desired-count 5
```

### Blue/Green Deployments
```bash
aws ecs update-service \
  --cluster <cluster> \
  --service <service> \
  --force-new-deployment
```

See `docs/runbooks/operations.md` for complete operational procedures.

## 🧪 CI/CD Pipeline

### Validation (on PRs)
1. Terraform format, init, validate
2. TFLint checks
3. Checkov security scan
4. **OPA Policy: FAILS if NAT detected** ⚠️
5. Docker build tests
6. IAM Access Analyzer

### Deployment (on merge)
1. Terraform plan → manual approval → apply
2. Build and push Docker images
3. ECS service deployment
4. Post-deploy smoke tests

## 💰 Cost Optimization

### Development
- Fargate Spot for workers
- EFS One-Zone
- Scale workers to zero off-hours
- Smaller instance types

### Production
- Reserved Capacity for baseline
- EFS Standard with lifecycle policies
- Right-sized RDS instances
- 30-day log retention

**Estimated Monthly Cost (Dev)**: $150-250
**Estimated Monthly Cost (Prod)**: $500-800

No NAT Gateway charges ($0.045/GB) saves significant egress costs.

## 🚨 Critical Policies

### NO NAT ALLOWED
Pipeline **WILL FAIL** if NAT gateway detected. This is enforced by:
- OPA policy in `infra/policies/no-nat.rego`
- CI validation in `.github/workflows/validate.yml`
- Grep checks in pre-commit hooks

### VPC Endpoints Required
All AWS service communication must use VPC endpoints:
- S3 (Gateway endpoint)
- ECR api + dkr
- CloudWatch Logs
- EventBridge
- STS
- Secrets Manager
- Systems Manager
- EFS
- KMS

## 📚 Documentation

- **Operations Runbook**: `docs/runbooks/operations.md`
- **Architecture Decisions**: `docs/adr/`
- **Terraform Modules**: See individual module README files

## 🆘 Support

- **Issues**: Create GitHub issue
- **On-Call**: oncall@example.com
- **Slack**: #airflow-support

## 📜 License

[Your License Here]

## 🙏 Acknowledgments

Built following AWS best practices for NAT-free ECS deployments and Airflow production patterns.
