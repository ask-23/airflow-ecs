# ECS Service Contracts

- web:
  - Port 8080 → ALB target group.
  - Health: `GET /health` (200 OK).
- scheduler:
  - Must pass `airflow jobs check --job-type scheduler`.
- worker:
  - Must pass `airflow jobs check --job-type worker`.

# Volumes

- EFS: `/opt/airflow/{dags,plugins}` mounted RW by all services + sidecar.

# Env Vars (examples)

- `AIRFLOW__CORE__EXECUTOR=CeleryExecutor`
- `AIRFLOW__CELERY__BROKER_URL=redis://...:6379/0`
- `AIRFLOW__CELERY__RESULT_BACKEND=db+postgresql://...`
- `AIRFLOW__CORE__REMOTE_LOGGING=True`
- `AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER=s3://<bucket>/logs/`
- `AIRFLOW__CORE__LOAD_EXAMPLES=False`
- Secrets: pulled at runtime from Secrets Manager.

# S3 DAG Source

- `s3://<org>-airflow-dags/<env>/` → EFS via sidecar sync (≤30s cadence).
