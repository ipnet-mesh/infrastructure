# Tasks: Add Prometheus Data Volume to S3 Backup Service

> Generated from `plan.md` on 2026-05-17

> **Pre-deploy manual step**: Run `docker volume create prometheus_data` on the production host before restarting the monitoring stack.

## Monitoring Stack Changes

- [x] Make prometheus_data an external volume in `compose/monitoring.yml`
  - [x] Change `prometheus_data:` under the top-level `volumes` section to `prometheus_data: external: true` (line 79)
- [x] Increase Prometheus TSDB retention to 30 days in `compose/monitoring.yml`
  - [x] Add `--storage.tsdb.retention.time=30d` to the `exec /bin/prometheus` command on line 38

## Backup Stack Changes

- [x] Mount prometheus_data in the backup service in `compose/backup.yml`
  - [x] Add `- prometheus_data:/backup/prometheus:ro` to the backup service `volumes` list (after line 22)
- [x] Declare prometheus_data as an external volume in `compose/backup.yml`
  - [x] Add `prometheus_data: external: true` under the top-level `volumes` section (after line 31)

## Verification

NONE
