# OPA (snippets)

deny[msg] { input.resource.type == "aws_nat_gateway"; msg := "NAT not allowed" }
deny[msg] { some sg in input.security_groups; sg.cidr == "0.0.0.0/0"; msg := "No wide-open SGs" }

# IAM checks (human-readable policies)

- task:worker may read only `s3://<org>-airflow-dags/<env>/*` and `s3://<org>-airflow-logs/<env>/*`
- task:s3sync may List/Get on dags bucket; no Put/Delete outside EFS path.
- kms: key policies limited to roles above.
