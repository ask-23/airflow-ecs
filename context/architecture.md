Core architecture

RDS Postgres for Airflow metadata.

Fargate services: web, scheduler, workers (CeleryExecutor). ElastiCache Redis for Celery broker; keep images slim to reduce cold starts.
hoop.dev

EFS shared volume mounted at /opt/airflow/dags and /opt/airflow/plugins. Pair with s3-sync / git-sync sidecar to pull DAGs on a cadence or event. (Sidecar pattern is well-trodden; Airflow Helm added first-class s3Sync for the same reason.)
GitHub
+1

S3 remote logging from workers; keep web read-only.

ALB for web/API with sane timeouts and health checks; don’t forget the ALB’s cost when it idles.
Dataquest

Deployment & config

Single source of truth: DAGs live in Git → CI syncs to S3 (or Git tag → ECR build if you prefer bake-in). Example CI step: aws s3 sync dags/ s3://your-bucket/dags --delete.
Medium

Task roles: per domain/DAG family rather than per-task. Keep policies human-readable; run IAM Access Analyzer as a check.
hoop.dev

Health checks:

Web/API: /health with a generous startPeriod (Airflow can be slow on first boot).

Scheduler/worker: container-level airflow jobs check or /health. Stagger service deployments to avoid first-run stampedes.

Scaling: Fargate service autoscaling on queue depth & task duration; cap worker concurrency in airflow.cfg to stop thundering herds.
