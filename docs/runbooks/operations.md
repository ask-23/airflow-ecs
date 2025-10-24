# Airflow 3.1 ECS Operations Runbook

## Table of Contents
1. [First Deploy](#first-deploy)
2. [Day-2 Operations](#day-2-operations)
3. [Troubleshooting](#troubleshooting)
4. [Disaster Recovery](#disaster-recovery)

## First Deploy

### Prerequisites
- AWS CLI configured with appropriate credentials
- Terraform >= 1.12 installed
- Docker installed for image builds
- ACM certificate created for ALB

### Steps

1. **Initialize Terraform Backend**
```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://pathwai-terraform-state --region us-east-1
aws s3api put-bucket-versioning --bucket pathwai-terraform-state --versioning-configuration Status=Enabled
```

2. **Store DB Password in Secrets Manager**
```bash
aws secretsmanager create-secret \
  --name pathwai-airflow-dev/db-password \
  --secret-string "SECURE_PASSWORD_HERE"
```

3. **Deploy Infrastructure**
```bash
cd infra/envs/dev
terraform init
terraform plan
terraform apply
```

4. **Build and Push Docker Images**
```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 381492153064.dkr.ecr.us-east-1.amazonaws.com

# Build and push all images
cd app/docker
docker build -t 381492153064.dkr.ecr.us-east-1.amazonaws.com/airflow-base:latest airflow-base/
docker push 381492153064.dkr.ecr.us-east-1.amazonaws.com/airflow-base:latest

docker build -t 381492153064.dkr.ecr.us-east-1.amazonaws.com/airflow-web:latest airflow-web/
docker push 381492153064.dkr.ecr.us-east-1.amazonaws.com/airflow-web:latest

docker build -t 381492153064.dkr.ecr.us-east-1.amazonaws.com/airflow-scheduler:latest airflow-scheduler/
docker push 381492153064.dkr.ecr.us-east-1.amazonaws.com/airflow-scheduler:latest

docker build -t 381492153064.dkr.ecr.us-east-1.amazonaws.com/airflow-worker:latest airflow-worker/
docker push 381492153064.dkr.ecr.us-east-1.amazonaws.com/airflow-worker:latest

docker build -t 381492153064.dkr.ecr.us-east-1.amazonaws.com/sidecar-s3sync:latest sidecar-s3sync/
docker push 381492153064.dkr.ecr.us-east-1.amazonaws.com/sidecar-s3sync:latest
```

5. **Initialize Airflow Database**
```bash
# Run db init task
aws ecs run-task \
  --cluster pathwai-airflow-dev-cluster \
  --task-definition pathwai-airflow-dev-scheduler \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx]}" \
  --overrides '{"containerOverrides":[{"name":"airflow-scheduler","command":["airflow","db","init"]}]}'
```

6. **Create Admin User**
```bash
aws ecs run-task \
  --cluster pathwai-airflow-dev-cluster \
  --task-definition pathwai-airflow-dev-scheduler \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx]}" \
  --overrides '{"containerOverrides":[{"name":"airflow-scheduler","command":["airflow","users","create","--username","admin","--password","admin","--firstname","Admin","--lastname","User","--role","Admin","--email","admin@example.com"]}]}'
```

7. **Verify Deployment**
- Check ALB health: `aws elbv2 describe-target-health --target-group-arn <tg-arn>`
- Access Airflow UI via ALB DNS name
- Verify DAG sync: Upload a test DAG to S3, wait 60s, check UI

## Day-2 Operations

### Updating DAGs
DAGs sync automatically from S3 to EFS every ~30s:
```bash
# Upload new/modified DAGs
aws s3 sync ./dags s3://pathwai-airflow3-dags/dev/ --delete --exact-timestamps
# Wait up to 60s for sidecar to sync
```

### Scaling Workers
Workers autoscale based on CPU/memory, but manual scaling:
```bash
aws ecs update-service \
  --cluster pathwai-airflow-dev-cluster \
  --service pathwai-airflow-dev-worker \
  --desired-count 5
```

### Blue/Green Deployment
1. Update task definition with new image
2. Force new deployment: `aws ecs update-service --cluster <cluster> --service <service> --force-new-deployment`
3. Monitor old tasks draining: `aws ecs describe-services --cluster <cluster> --services <service>`

### Rotating Secrets
1. Update secret in Secrets Manager
2. Force service redeployment to pick up new secret

### Resizing RDS
1. Modify instance class: `terraform apply` with updated `instance_class`
2. RDS applies change during maintenance window or immediately if specified

## Troubleshooting

### Tasks Not Starting
- Check security groups allow traffic from ALB to tasks (port 8080)
- Verify VPC endpoints are functional: `aws ec2 describe-vpc-endpoints`
- Check ECS task stopped reason: `aws ecs describe-tasks --cluster <cluster> --tasks <task-id>`

### DAGs Not Syncing
- Check sidecar container logs: `aws logs tail /aws/ecs/pathwai-airflow-dev/sidecar --follow`
- Verify S3 sync sidecar IAM role has s3:GetObject, s3:ListBucket permissions
- Check EFS mount is accessible from tasks

### Health Checks Failing
- Increase `startPeriod` in task definition if cold starts are slow
- Check ALB idle timeout (should be >= 120s)
- Verify /health endpoint responds: `curl http://<task-ip>:8080/health`

### Scheduler Not Processing DAGs
- Check scheduler logs: `aws logs tail /aws/ecs/pathwai-airflow-dev/scheduler --follow`
- Verify DB connection string is correct
- Check Redis connection for Celery broker

### Workers Not Picking Up Tasks
- Verify Redis connection string includes TLS (`rediss://`)
- Check worker concurrency setting in airflow.cfg
- Scale workers up manually if needed

## Disaster Recovery

### RDS Failure
RDS has automated backups with 7-day retention:
```bash
# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier pathwai-airflow-dev-restored \
  --db-snapshot-identifier <snapshot-id>

# Update connection string in task definitions
```

### EFS Failure
EFS data is persisted and replicated within AZ:
- For One-Zone: Data loss if AZ fails (dev only)
- For Standard: Replicated across multiple AZs (prod)

### Complete Environment Recovery
```bash
# Destroy and recreate
cd infra/envs/dev
terraform destroy
terraform apply

# Redeploy images and reinitialize
```

### Rollback Deployment
```bash
# Rollback to previous task definition
aws ecs update-service \
  --cluster <cluster> \
  --service <service> \
  --task-definition <previous-revision>
```

## Monitoring & Alerts

### Key Metrics
- Scheduler heartbeat (should update every 5s)
- Worker queue depth (Celery)
- Task failure rate
- ALB 5xx errors
- ECS service desired vs running count

### CloudWatch Alarms
Created via Terraform in monitoring module:
- Scheduler heartbeat stopped
- High task failure rate (>10%)
- Worker queue depth growing
- ALB unhealthy targets
- RDS connection failures

## Performance Tuning

### Slow DAG Processing
- Increase scheduler CPU/memory
- Reduce DAG parsing interval
- Optimize DAG code

### High Worker Latency
- Increase worker_concurrency in airflow.cfg
- Scale up worker count
- Optimize task code

### Database Performance
- Increase RDS instance size
- Enable Performance Insights
- Add read replicas if needed

## Cost Optimization

### Development Environment
- Use Fargate Spot for workers
- Use EFS One-Zone
- Scale workers to zero off-hours
- Use smaller instance types

### Production Environment
- Right-size based on actual usage
- Use Reserved Capacity for predictable workloads
- Enable EFS lifecycle policies
- Set appropriate log retention periods

## Security Best Practices

- Rotate database passwords regularly
- Review IAM roles quarterly with IAM Access Analyzer
- Keep Docker images updated with security patches
- Enable CloudTrail for audit logging
- Use SSO for Airflow web access via ALB OIDC

## Contacts

- Infrastructure Team: infra@example.com
- On-Call: oncall@example.com
- Slack: #airflow-support
