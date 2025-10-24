# Airflow Web Service

FROM 381492153064.dkr.ecr.us-east-1.amazonaws.com/airflow-base:latest

USER root

# Health check endpoint setup
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && apt-get clean \
    && rm-rf /var/lib/apt/lists/*

USER airflow

# Copy web-specific config
COPY webserver_config.py /opt/airflow/webserver_config.py

# Expose web port
EXPOSE 8080

# Web server entrypoint
CMD ["airflow", "webserver"]
