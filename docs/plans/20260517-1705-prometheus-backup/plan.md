# Add Prometheus Data Volume to S3 Backup Service

## Summary

Add the `prometheus_data` Docker volume to the existing Backblaze B2 backup service so that Prometheus time-series data is included in the daily off-site backup schedule. This ensures historical metrics are recoverable in the event of data loss or infrastructure migration.

## Background & Motivation

The backup service (`compose/backup.yml`) currently performs daily snapshots of three volumes: `hub-prod_data`, `hub-stg_data`, and `postgres_data`. The Prometheus instance (`compose/monitoring.yml`) stores its TSDB data in a named Docker volume (`prometheus_data`, line 79 of `monitoring.yml`), which is **not** included in any backup. If the volume is lost, all historical metrics and alert state are gone permanently. Given that this infrastructure already has a backup pipeline to Backblaze B2, adding one more volume is low-effort and high-value.

**Note on disk usage**: Adding `prometheus_data` as a 4th volume increases the
per-backup tarball size. With `BACKUP_RETENTION_DAYS=30`, this means 30 larger
tarballs accumulating in B2 over time. Ensure the host disk has enough free
space for the larger tarball during the temp stage.

No prior plans exist in `docs/plans/`.

## Goals

- Include `prometheus_data` in the daily B2 backup alongside existing volumes
- Increase Prometheus TSDB retention from the default 15 days to 30 days
- Preserve the existing backup schedule, retention policy, and naming conventions
- Keep the change minimal and consistent with current patterns

## Non-Goals

- Changing backup frequency, retention, or compression settings
- Backing up Alertmanager state (it is stateless / re-derivable from config)
- Migrating Prometheus to a remote-write or long-term storage backend (e.g., Thanos, Cortex)

## Requirements

### Functional Requirements

- The backup service must mount `prometheus_data` as read-only and include it in the daily tarball
- The backed-up data must be restorable to a fresh Prometheus instance

### Technical Requirements

- `prometheus_data` must be declared as an **external** volume in `compose/backup.yml` so Docker Compose does not try to create it under the backup project namespace
- The Prometheus stack (`compose/monitoring.yml`) must also declare `prometheus_data` as **external** so both stacks reference the same Docker volume
- The mount path in the backup container should follow the existing naming convention: `/backup/prometheus:ro`
- Prometheus must be started with `--storage.tsdb.retention.time=30d` (currently unset, defaults to 15d)

## Implementation Plan

### Phase 1: Externalise the Prometheus volume and increase retention

- In `compose/monitoring.yml`, change the `prometheus_data` volume declaration from a plain named volume to `external: true`
- In the Prometheus entrypoint command, add `--storage.tsdb.retention.time=30d` to the `exec /bin/prometheus` invocation
- **Existing data**: The old stack-local volume (`monitoring_prometheus_data`) will not be migrated. Historical metrics in the old volume will be discarded; new data begins after restart.
- Create the external volume before deploying: `docker volume create prometheus_data`
- Restart the monitoring stack: `docker compose -f compose/monitoring.yml up -d`

### Phase 2: Add volume to backup service

- In `compose/backup.yml`, add `prometheus_data:/backup/prometheus:ro` to the backup service `volumes`
- Add `prometheus_data` with `external: true` to the top-level `volumes` section
- Restart the backup service: `docker compose -f compose/backup.yml up -d`

### Phase 3: Verify

- Trigger an ad-hoc backup:
  ```
  docker exec backup backup
  ```
- Confirm the backup was uploaded successfully:
  ```
  docker compose -f compose/backup.yml logs --tail=50
  ```
- Download and inspect the latest tarball to confirm a `prometheus/` directory is present
- Restore procedure is deferred to a future plan

## References

- `compose/backup.yml` — current backup service definition
- `compose/monitoring.yml` — Prometheus service and volume definition (line 25, line 79)

## Review

**Status**: Approved with Changes

**Reviewed**: 2026-05-17

### Resolutions

- **Conflict — Non-Goals contradicted Implementation Plan**: Removed "Making prometheus_data an external volume" from Non-Goals. The plan explicitly requires it.
- **Gap — Missing data migration step**: Accepted data loss. Existing metrics in the stack-local volume (`monitoring_prometheus_data`) will not be migrated to the new external volume.
- **Gap — Verification command not specified**: Added `docker exec backup backup` for ad-hoc backup trigger and expanded verification steps.
- **Risk — Backup disk usage**: Added note in Background warning that the 4th volume increases per-backup tarball size, and with 30-day backup retention this multiplies B2 storage usage.
- **Ambiguity — Volume creation order**: Clarified Phase 1: `docker volume create prometheus_data` is an explicit prerequisite before docker compose up.
- **Open Question — Restore procedure**: Deferred to a future plan. No restore steps included.

### Remaining Action Items

- (none)
