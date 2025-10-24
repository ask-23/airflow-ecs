# Definition of Done (DoD)

1) One-command deploy to **dev** (no NAT).  
2) Airflow UI up behind internal ALB + SSO.  
3) DAG pushed to S3 → visible in UI ≤60s.  
4) Autoscaling: queue depth triggers worker scale-out; off-hours scale-to-zero proven.  
5) Logs present in S3; CW dashboards live.  
6) Alarms: scheduler heartbeat, ALB 5xx, queue depth, high failure rate.  
7) Runbooks cover deploy, rollback, upgrade, restore, stuck task, disk pressure.

# Tests

- **Cold start** (first boot) passes health without flapping.
- **Synthetic DAG pack**: quick success, slow task, failing task, external sensor.
- **Chaos**: kill a worker → tasks rescheduled, SLA respected.
- **Security**: secrets only via Secrets Manager; endpoint-only egress.

# Artifacts

- `docs/runbooks/*.md`
- `tests/dags/*`
- CW dashboard JSON; alarm ARNs.
