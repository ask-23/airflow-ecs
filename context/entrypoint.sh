#!/usr/bin/env sh
set -euo pipefail

: "${DAGS_BUCKET:?DAGS_BUCKET required}"
: "${ENV:?ENV required}"

base_sleep=30

while true; do
  aws s3 sync "s3://${DAGS_BUCKET}/${ENV}/" /opt/airflow/dags --exact-timestamps --delete || true
  # jitter 25–40s
  s=$(( base_sleep + (RANDOM % 15) ))
  sleep "$s"
done
