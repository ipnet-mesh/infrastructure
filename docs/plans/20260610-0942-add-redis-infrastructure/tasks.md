# Tasks: Add Redis Cache to Infrastructure Stack

> Generated from `plan.md` on 2026-06-10

## Compose Service Definition

- [x] Create `compose/redis.yml`
  - [x] Write header comment block (purpose, prerequisites, usage)
  - [x] Define `redis` service with `redis:7-alpine` image and `container_name: redis`
  - [x] Configure `restart: unless-stopped`
  - [x] Attach `proxy-net` external network
  - [x] Set command: `redis-server --appendonly yes --maxmemory 128mb --maxmemory-policy allkeys-lru`
  - [x] Mount `redis_data:/data` external volume
  - [x] Add healthcheck with `redis-cli ping` (10s interval, 5s timeout, 3 retries)
  - [x] Declare `proxy-net` as external network (under `networks:` top-level key)
  - [x] Declare `redis_data` as external volume (under `volumes:` top-level key)

## Documentation — README.md

- [x] Update `README.md`
  - [x] Add Redis row to the Components table (service name, description, ports/exposure)
  - [x] Add `docker volume create redis_data` to the "Create Network and Volumes" section
  - [x] Add Redis start/stop/logs commands to Operational Commands
  - [x] Add `redis_data` volume to the directory structure diagram
  - [x] Add Redis service to the Architecture ASCII diagram

## Documentation — AGENTS.md

- [x] Update `AGENTS.md`
  - [x] Add Redis entry to the Services section (concise description matching existing style)
  - [x] Add Redis start/stop/logs commands to Common Development Commands
  - [x] Add `redis_data` to the "Network and Volume Setup" section
  - [x] Add `compose/redis.yml` row to the Configuration Files table

## Documentation — .env.example

- [x] Update `.env.example`
  - [x] Add comment-only section for Redis under `# =============================================================================`
  - [x] Section header: `# REDIS (shared cache)`
  - [x] Body: note that Redis runs on proxy-net with no auth, config in compose/redis.yml

## Deployment & Verification

- [ ] Create external volume: `docker volume create redis_data`
- [ ] Start Redis: `docker compose -f compose/redis.yml up -d`
- [ ] Verify container is running: `docker compose -f compose/redis.yml ps`
- [ ] Verify healthcheck passes: `docker compose -f compose/redis.yml logs redis`
- [ ] Verify connectivity from another proxy-net container (e.g. `docker compose -f compose/postgres.yml exec postgres nslookup redis` or similar)
