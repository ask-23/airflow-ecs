# Quickstart (dev)

1) `terraform -chdir=infra/envs/dev init && terraform apply`
2) Push sample DAGs: `aws s3 sync ./dags s3://<bucket>/dev/ --delete`
3) Open Airflow (internal ALB) → SSO → confirm DAGs visible.

# Common Ops

- Rotate secrets: update in Secrets Manager → restart only web if UI creds changed.
- Scale workers: adjust AS policy thresholds (queue depth, duration).
- Rollback: revert task def SHA → redeploy service; Terraform state is source of truth.
- Upgrade Airflow: build new images with pinned `constraints.txt`, canary deploy (scheduler last), verify heartbeat.

# Break-glass

- Stuck tasks: `airflow tasks clear -t <task> -d <dag> --reset-dagruns`
- Scheduler down: check Redis + RDS health; run `airflow db check`.
- EFS full: increase throughput or prune; verify lifecycle.
