Tech Lead / Architect

Owns overall spec, decides trade-offs, enforces conventions.

Delivers: architecture diagram, ADRs, interface contracts, final README.

Infra/IaC Engineer

Writes Terraform for VPC, endpoints (no NAT), ECS/Fargate, EFS, RDS Postgres, ElastiCache Redis, ALB, IAM.

Delivers: reusable modules, env overlays (dev/stage/prod), tfdocs, tflint/checkov/opa gates.

App Packager (Airflow)

Builds Docker images (web, scheduler, worker, init), requirements/providers pinning, entrypoints, health checks.

Delivers: Dockerfiles, airflow.cfg, webserver_config.py, env.json, sidecar s3-sync container.

Sec/Net/Cost Engineer

Designs least-priv IAM, VPC endpoints, TLS/SSO, secret management, logging/retention, autoscaling & Fargate Spot policy, cost monitors.

QA / SRE & Runbooks

Provisions ephemeral env, runs acceptance tests, synthetic DAG test suite, rollback plan, dashboards/alarms, runbooks.
