# S3 Sync Sidecar - Minimal Alpine + AWS CLI v2

FROM alpine:3.19

# Install AWS CLI v2 and dependencies
RUN apk add --no-cache \
    aws-cli \
    bash \
    curl \
    && rm -rf /var/cache/apk/*

# Copy sync script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create mount point
RUN mkdir -p /opt/airflow/dags

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
