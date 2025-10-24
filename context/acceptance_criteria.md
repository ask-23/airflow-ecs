terraform plan is clean; tflint, checkov, and OPA policy pass; IAM Access Analyzer shows no broad grants.

Cluster runs without NAT; all external calls use VPC endpoints.

Web/API reachable behind internal ALB + SSO; TLS terminates at ALB; SGs least-priv.

DAG update path: commit → CI aws s3 sync → sidecar pulls → Airflow sees new DAG in ≤60s (no container restart).

Health checks do not flap on cold boot. No 502s/504s during deploy.

Workers autoscale on Celery queue; off-hours scale-to-zero demonstrated.

Logs in S3 partitioned by date; retention set; CW alarms: scheduler heartbeat, task failure rate, queue depth, 5xx on ALB.

Runbook covers: first deploy, blue/green update, rollback, rotating keys, resizing RDS, recovering broken DAG, handling stuck tasks.
