# Airflow 3.1 Base Image - Slim for fast cold starts

FROM apache/airflow:3.1.0-python3.11

USER root

# Install required system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER airflow

# Copy constraints file
COPY constraints.txt /tmp/constraints.txt

# Install only required providers
RUN pip install --no-cache-dir \
    --constraint /tmp/constraints.txt \
    apache-airflow-providers-amazon \
    apache-airflow-providers-celery \
    apache-airflow-providers-postgres

# Create required directories
RUN mkdir -p /opt/airflow/dags /opt/airflow/plugins /opt/airflow/logs

WORKDIR /opt/airflow
