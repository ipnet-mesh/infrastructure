# Add Redis Cache to Infrastructure Stack

## Summary

Add a Redis 7 service to the infrastructure stack as a standalone `compose/redis.yml` file, providing a shared in-memory cache available to all services on the `proxy-net` network. The service will use the Alpine image with AOF persistence, a 128 MB memory cap with LRU eviction, and a named external Docker volume for data durability.

## Background & Motivation

The infrastructure stack currently provides shared PostgreSQL, MQTT, monitoring, and identity services. No caching layer exists. As hub instances and supporting services grow, a shared Redis instance will enable session caching, API response caching, and rate-limit counters without adding load to PostgreSQL.

Recent activity (git history) shows incremental infrastructure hardening — Prometheus backup integration, AGENTS.md/README production safeguards, and config updates. Adding Redis follows the established pattern of self-contained `compose/*.yml` files with external volumes and network membership.

No prior plans address caching.

## Goals

- Provide a shared Redis 7 (Alpine) cache accessible to all services on `proxy-net`
- Persist Redis data via AOF with an external Docker volume
- Follow existing compose file conventions (header comments, external network, external volume, healthcheck)
- Update all documentation to reflect the new service

## Non-Goals

- Configuring Redis replication, clustering, or sentinel
- Setting up Redis authentication (internal network only, consistent with existing services like PostgreSQL which also has no password on `proxy-net`)
- Adding Redis to the B2 backup (cache data is ephemeral by nature; AOF persistence is for warm-restart only)
- Exposing Redis through Traefik (internal-only access)
- Adding per-service Redis configuration variables to `.env` (all tuning is hardcoded in the compose command; a future plan can parameterise if needed)

## Requirements

### Functional Requirements

- Redis must be reachable by any container on `proxy-net` at hostname `redis` on port `6379`
- Data must survive container restarts (AOF persistence on a named Docker volume)
- Memory must be capped at 128 MB with `allkeys-lru` eviction policy
- A healthcheck must confirm Redis is responsive via `redis-cli ping`

### Technical Requirements

- Service defined in `compose/redis.yml`, consistent with existing compose file patterns (header comment block, external `proxy-net` network, external volume)
- `redis_data` declared as an **external** volume — created manually before first deploy
- Image: `redis:7-alpine`
- Container name: `redis` (consistent with other infra services like `postgres`, `mqtt`)
- Restart policy: `unless-stopped`
- No Traefik labels — Redis is internal-only

## Implementation Plan

### Phase 1: Create compose file and volume

- Create `compose/redis.yml` with the Redis service definition:
  ```yaml
  # Redis Cache
  # Shared in-memory cache for all services on proxy-net
  #
  # Prerequisites:
  #   - proxy-net external network exists
  #   - redis_data external volume exists (docker volume create redis_data)
  #
  # Usage:
  #   docker compose -f compose/redis.yml up -d

  services:
    redis:
      image: redis:7-alpine
      container_name: redis
      restart: unless-stopped
      networks:
        - proxy-net
      command: redis-server --appendonly yes --maxmemory 128mb --maxmemory-policy allkeys-lru
      volumes:
        - redis_data:/data
      healthcheck:
        test: ["CMD", "redis-cli", "ping"]
        interval: 10s
        timeout: 5s
        retries: 3

  networks:
    proxy-net:
      external: true

  volumes:
    redis_data:
      external: true
  ```

- Create the external volume: `docker volume create redis_data`
- Do **not** update `compose/backup.yml` — Redis cache data is ephemeral and excluded from B2 backups

### Phase 2: Update documentation

- **`README.md`**:
  - Add Redis row to the Components table
  - Add `redis_data` to the "Create Network and Volumes" section
  - Add Redis start/stop/logs commands to Operational Commands
  - Add `redis_data` to the directory structure diagram under `compose/`
  - Update the Architecture ASCII diagram if appropriate

- **`AGENTS.md`**:
  - Add Redis entry to the Services section
  - Add Redis start/stop/logs commands to Common Development Commands
  - Add `redis_data` to the "Network and Volume Setup" section
  - Add `compose/redis.yml` row to the Configuration Files table

- **`.env.example`**:
  - No new variables required (Redis has no auth, no configurable ports for this use case). Add a comment-only section to acknowledge Redis exists:
    ```
    # =============================================================================
    # REDIS (shared cache)
    # =============================================================================
    # Redis runs on proxy-net with no authentication.
    # Configuration is in compose/redis.yml (memory, persistence, eviction).
    ```

### Phase 3: Deploy (manual, operator action)

- Operator runs: `docker volume create redis_data`
- Operator runs: `docker compose -f compose/redis.yml up -d`
- Operator verifies: `docker compose -f compose/redis.yml logs redis`

## Risks

- **AOF file size**: With `maxmemory 128mb` and `allkeys-lru` eviction, the AOF file is naturally bounded — keys evicted by LRU are removed from the dataset before AOF grows unbounded. No explicit AOF rewrite tuning is needed at this scale.
- **No monitoring**: Redis will not be scraped by Prometheus initially. Cache hit rates, memory usage, and eviction counts are not visible. This can be added in a future plan if operational visibility is needed.

## Open Questions

- **Should Redis data be included in B2 backups?** Resolved: no. Cache data is ephemeral. AOF persistence is for warm-restart only, not disaster recovery.

## References

- `compose/postgres.yml` — pattern for external-volume infra services
- `compose/backup.yml` — current backup volume list (Redis not included)
- `docs/plans/20260517-1705-prometheus-backup/plan.md` — prior plan establishing the external-volume pattern

## Review

**Status**: Approved

**Reviewed**: 2026-06-10

### Resolutions

- **Decision — Image tag**: Keep `redis:7-alpine` hardcoded. No env var parameterisation (consistent with MQTT pattern).
- **Decision — Prometheus monitoring**: Skip for now. Redis metrics scraping is deferred to a future plan.
- **Gap — AGENTS.md Configuration Files table**: Added `compose/redis.yml` row to the AGENTS.md update checklist.
- **Risk — AOF file growth**: Confirmed bounded by 128 MB maxmemory with allkeys-lru. No rewrite tuning needed.
- **Gap — Backup exclusion**: Made explicit in Phase 1 that `compose/backup.yml` is not updated.

### Remaining Action Items

- (none)
