# Goal

Slim, pinned Airflow 3.1 images (web/scheduler/worker) + `s3-sync` sidecar. Fast boot, stable deps.

# Base

- `apache/airflow:3.1.*` (match constraints).
- Add only required providers; produce `constraints.txt`.

# Images

- `airflow-web`, `airflow-scheduler`, `airflow-worker`: common base layer, separate entrypoints.
- Health: `/health` endpoint; `airflow jobs check --job-type <scheduler|worker>` for internal checks.
- Env via files: `AIRFLOW__...` style; secrets from Secrets Manager.

# DAGs/Plugins

- **Do not bake**. Use EFS + sidecar pull from S3 every ~30s with ETag short-circuit.

# Sidecar (s3-sync)

- Tiny alpine + AWS CLI v2.
- Logic: sync → hash compare → backoff (jitter) → repeat.
- Writes to the same EFS path.

# Logging

- Workers write to S3 remote logging; CW for service/container logs.

# Acceptance

Fresh deploy lists sample DAGs without restarts; add DAG to S3 → appears in UI ≤60s.
