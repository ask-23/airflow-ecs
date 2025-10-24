root: airflow-ecs
dirs:

- docs/adr
- docs/runbooks
- infra/modules/{vpc,vpc_endpoints,ecs_cluster,ecs_service_airflow,rds_postgres,redis,efs,alb,iam}
- infra/envs/{dev,prod}
- infra/policies
- app/docker/{airflow-base,airflow-web,airflow-scheduler,airflow-worker,sidecar-s3sync}
- app/config
- ci/github-actions
- dags
- plugins
- tests/dags
files:
- README.md
- docs/architecture.png
- docs/runbooks/operations.md
- infra/envs/dev/{main.tf,variables.tf,terraform.tfvars}
- infra/envs/prod/{main.tf,variables.tf,terraform.tfvars}
- ci/github-actions/{validate.yml,deploy.yml,dag-sync.yml}
- app/config/{airflow.cfg,webserver_config.py,constraints.txt,env.example}
- app/docker/sidecar-s3sync/entrypoint.sh
