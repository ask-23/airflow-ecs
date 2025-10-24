# Sidecar Behavior

Loop:

1) `aws s3 sync s3://$DAGS_BUCKET/$ENV/ /opt/airflow/dags --exact-timestamps --delete`
2) Sleep with jitter (base 30s, ±10s)
3) If 5 consecutive no-op syncs → backoff to 60–90s
Logs: write to stdout; surface metrics via `--dryrun` detection if needed.

# Env

- `DAGS_BUCKET`, `ENV`
- AWS creds via task role
- Mount: EFS at `/opt/airflow/dags`

# Exit

Never exit non-zero unless creds invalid or mount missing.
