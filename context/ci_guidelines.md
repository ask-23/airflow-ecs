# validate.yml (PR)

- terraform fmt, init, validate
- tflint
- checkov
- OPA policy (deny NAT, deny 0.0.0.0/0, require endpoints)
- docker build (no push) for all images
- IAM Access Analyzer (policy diff)

# deploy.yml (main/prod)

- plan → manual approval → apply
- image build & push → task definition rev → service deploy
- post-deploy smoke: /health, scheduler heartbeat

# dag-sync.yml

- on changes to `/dags/**`:
  - `aws s3 sync ./dags s3://<org>-airflow-dags/<env>/ --delete`
