#!/bin/bash
set -euo pipefail

# Environment variables
DAGS_BUCKET="${DAGS_BUCKET:?DAGS_BUCKET is required}"
ENV="${ENV:?ENV is required}"
BASE_SLEEP=30
JITTER=10
NO_OP_THRESHOLD=5
BACKOFF_SLEEP=60

# S3 source and EFS destination
S3_SOURCE="s3://${DAGS_BUCKET}/${ENV}/"
EFS_DEST="/opt/airflow/dags"

# Counters
no_op_count=0
current_sleep=$BASE_SLEEP

echo "S3 Sync Sidecar starting..."
echo "Source: ${S3_SOURCE}"
echo "Destination: ${EFS_DEST}"

# Verify mount is available
if [ ! -d "$EFS_DEST" ]; then
    echo "ERROR: EFS mount not found at ${EFS_DEST}"
    exit 1
fi

# Main sync loop
while true; do
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Starting sync..."
    
    # Perform sync with exact timestamps and delete
    if aws s3 sync "$S3_SOURCE" "$EFS_DEST" --exact-timestamps --delete 2>&1 | tee /tmp/sync.log; then
        # Check if sync was a no-op
        if grep -q "download\|upload\|delete" /tmp/sync.log; then
            echo "Changes detected and synced"
            no_op_count=0
            current_sleep=$BASE_SLEEP
        else
            echo "No changes detected"
            no_op_count=$((no_op_count + 1))
            
            # Apply backoff after consecutive no-ops
            if [ $no_op_count -ge $NO_OP_THRESHOLD ]; then
                current_sleep=$((BACKOFF_SLEEP + RANDOM % (JITTER * 2)))
                echo "Backing off: ${no_op_count} consecutive no-ops, sleeping ${current_sleep}s"
            fi
        fi
    else
        echo "ERROR: Sync failed, will retry..."
    fi
    
    # Calculate sleep with jitter
    sleep_time=$((current_sleep + RANDOM % (JITTER * 2)))
    echo "Sleeping for ${sleep_time}s..."
    sleep $sleep_time
done
