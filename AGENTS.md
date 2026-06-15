# AGENTS.md

This file provides guidance to agentic development tools when working with code in this repository.

> **PRODUCTION ENVIRONMENT — READ BEFORE MAKING ANY CHANGES**
>
> This repository lives on and is deployed directly to a **production server**. Every compose file, config change, and script in this repo affects live services.
>
> - **Do NOT run `docker compose up`, `down`, `restart`, or any other lifecycle commands** as a verification step. These commands restart or recreate live containers and will impact production traffic.
> - **Do NOT run test suites, health checks, or smoke tests locally** — there is no local development environment for this stack. Verification must happen against the live deployment with care.
> - **Changes should be reviewed carefully before applying.** Prefer editing files, then having the operator manually apply them on the server.
> - When editing configs (Traefik, Prometheus, Alertmanager, etc.), note that the service must be reloaded on the server for changes to take effect — do not attempt this yourself.
> - If unsure whether a command is safe to run, **ask first**.

## Project Overview

This is the infrastructure repository for IPNet Mesh — a Docker Compose-based setup providing:

- **Traefik** reverse proxy with automatic HTTPS via Cloudflare DNS challenges
- **PostgreSQL** database server shared across services
- **MeshCore MQTT Broker** shared across all hub instances
- **LogTo** self-hosted OIDC identity provider
- **Prometheus & Alertmanager** monitoring hub API metrics with Discord alerts
- **Redis** shared in-memory cache with AOF persistence and LRU eviction
- **Volume Backup** to Backblaze B2 via `offen/docker-volume-backup`

Hub instances (MeshCore Hub) are deployed as separate independent compose stacks, each started from their own directory with wget'd compose files and a local `.env`.

## Architecture

All services connect to an external `proxy-net` Docker network. All infrastructure services live in a single root `docker-compose.yml` and are selected with `--profile`; each MeshCore Hub instance is a separate independent compose stack.

```
infrastructure/                hub-prod/              hub-stg/
├── docker-compose.yml         ├── docker-compose.*   ├── docker-compose.*
├── config/                    ├── etc/               ├── etc/
├── content/  ← shared volume  └── .env               └── .env
├── etc/
└── .env  (auto-loaded)
        │            │                  │
        └────────────┼──────────────────┘
               proxy-net (external)
```

### Services

- **Traefik**: Reverse proxy and TLS termination
  - Automatic HTTPS via Let's Encrypt with Cloudflare DNS challenge
  - Dynamic routing based on Docker labels
  - Ports: 80 (HTTP→HTTPS redirect), 443 (HTTPS)

- **MQTT Broker**: MeshCore MQTT Broker (WebSocket-only)
  - Shared by all hub instances
  - Traefik routes WSS traffic at `mqtt.<domain>/mqtt`
  - Subscriber authentication with role-based access

- **PostgreSQL**: Shared database server
  - Accessible to all services on `proxy-net`
  - Init SQL scripts in `etc/postgres/init/` for creating service databases and users
  - Data stored in `postgres_data` volume (live state, not backed up at file level)
  - Logical backups via `pg_dump`: the `docker-volume-backup.archive-pre` label runs `pg_dump -Fc` per non-template database into the `pgdump_data` volume (`/backups`); a `copy-post` hook removes the dumps after upload

- **Backup**: Volume backup to Backblaze B2 (via `offen/docker-volume-backup`)
  - Daily snapshots of: hub SQLite volumes (`hub-prod_data`, `hub-stg_data` → `/backup/sqlite/{prod,stg}`), PostgreSQL logical dumps (`pgdump_data` → `/backup/postgres`), Prometheus TSDB (`/backup/prometheus`), and host deployment config directories `${HOME}/data/apps/ipnet/{infrastructure,meshcore-hub}` → `/backup/{infrastructure,deployments}` (incl. their `.env` files)
  - `EXEC_FORWARD_OUTPUT=true` streams `pg_dump` output into the backup container logs
  - Any container labeled `docker-volume-backup.stop-during-backup=true` is stopped before snapshotting and restarted after (currently: Prometheus, for a crash-safe TSDB copy)
  - 30-day retention with automatic pruning
  - S3-compatible B2 endpoint

- **Monitoring**: Prometheus and Alertmanager
  - Prometheus scrapes hub API `/metrics` endpoint
  - Alertmanager routes alerts to Discord via Slack-compatible webhook
  - Exposed at `metrics.<domain>` and `alerts.<domain>` via Traefik
  - Scrape target configurable via `HUB_API_TARGET` (default: `hub-prod-api:8000`)
  - Prometheus is stopped during the daily backup (labeled `docker-volume-backup.stop-during-backup=true`) so its TSDB volume is snapshotted consistently

- **LogTo**: Self-hosted OIDC identity provider
  - Core OIDC endpoint exposed at `auth.<domain>` via Traefik (port 3001)
  - Admin console exposed at `id.<domain>` via Traefik (port 3002)
  - Uses shared PostgreSQL with dedicated database and user

- **Redis**: Shared in-memory cache
  - Accessible to all services on `proxy-net` at hostname `redis` on port 6379
  - AOF persistence with 128 MB memory cap and `allkeys-lru` eviction
  - Data stored in `redis_data` volume (not included in backups — ephemeral cache)

- **Hub Instances**: Independent MeshCore Hub stacks (collector, API, web)
  - Each has its own `.env` with unique `COMPOSE_PROJECT_NAME`
  - Storage via Docker volumes (namespaced per project)
  - Traefik labels for routing (via `docker-compose.traefik.yml`)
  - Content mounted from `../infrastructure/content`

## Environments

| Environment | Domain Pattern                   | Image Tag | Monitoring                 |
| ----------- | -------------------------------- | --------- | -------------------------- |
| Production  | `ipnt.uk`, `*.ipnt.uk`           | `v0.9.0`  | Yes (infrastructure stack) |
| Staging     | `beta.ipnt.uk`, `*.beta.ipnt.uk` | `main`    | No                         |

## Common Development Commands

### Infrastructure Services

All infrastructure services live in the root `docker-compose.yml` and are selected with `--profile`. Each service has its own profile (`traefik`, `mqtt`, `postgres`, `redis`, `monitoring`, `logto`, `backup`) and `--profile all` selects every service. The root `.env` is auto-loaded — no `--env-file` flag or shell export required.

```bash
# Start a service
docker compose --profile traefik up -d
docker compose --profile mqtt up -d
docker compose --profile postgres up -d
docker compose --profile redis up -d
docker compose --profile monitoring up -d
docker compose --profile logto up -d      # also starts postgres (depends_on)
docker compose --profile backup up -d
docker compose --profile all up -d        # everything

# Stop a service (or all)
docker compose --profile traefik down
docker compose --profile all down

# View logs
docker compose --profile traefik logs -f
docker compose --profile mqtt logs -f
docker compose --profile postgres logs -f
docker compose --profile redis logs -f
docker compose --profile monitoring logs -f
docker compose --profile logto logs -f
docker compose --profile backup logs -f
```

### Hub Instances

```bash
# Create a new instance
./scripts/bootstrap-instance.sh ../hub-prod v0.9.0 ipnt.uk

# Start
docker compose -f docker-compose.yml -f docker-compose.prod.yml \
  -f docker-compose.traefik.yml --profile core up -d

# Stop an instance
docker compose -f docker-compose.yml -f docker-compose.prod.yml \
  -f docker-compose.traefik.yml down

# Run database migrations
docker compose -f docker-compose.yml -f docker-compose.prod.yml \
  --profile migrate up db-migrate
```

### Network and Volume Setup (first time only)

```bash
docker network create proxy-net
docker volume create acme_data
docker volume create mqtt_data
docker volume create postgres_data
docker volume create pgdump_data
docker volume create prometheus_data
docker volume create redis_data
```

## Environment Variables

Copy `.env.example` to `.env` and configure. The root `.env` is auto-discovered by Compose (the `docker-compose.yml` lives at the repo root):

### Infrastructure Variables

| Variable                            | Description                                                       |
| ----------------------------------- | ----------------------------------------------------------------- |
| `ROOT_DOMAIN`                       | Root domain (e.g., `ipnt.uk`)                                     |
| `DNS_PROVIDER`                      | DNS provider for ACME (e.g., `cloudflare`)                        |
| `DNS_API_EMAIL`                     | Cloudflare account email                                          |
| `DNS_API_TOKEN`                     | Cloudflare DNS API token                                          |
| `ACME_EMAIL`                        | Email for Let's Encrypt certificates                              |
| `TRAEFIK_HTTP_PORT`                 | Host port for HTTP (default: `80`)                                |
| `TRAEFIK_HTTPS_PORT`                | Host port for HTTPS (default: `443`)                              |
| `TRAEFIK_LOG_LEVEL`                 | Traefik log level (default: `INFO`)                               |
| `MQTT_PORT`                         | MQTT WebSocket port (default: `1883`)                             |
| `MQTT_USERNAME`                     | MQTT subscriber username                                          |
| `MQTT_PASSWORD`                     | MQTT subscriber password                                          |
| `MQTT_TOKEN_AUDIENCE`               | JWT audience for auth tokens                                      |
| `POSTGRES_IMAGE_TAG`                | PostgreSQL Docker image tag (default: `17-alpine`)                |
| `POSTGRES_USER`                     | PostgreSQL superuser username                                      |
| `POSTGRES_PASSWORD`                 | PostgreSQL superuser password                                      |
| `POSTGRES_LOGTO_USERNAME` | PostgreSQL user for LogTo (default: `logto`) |
| `POSTGRES_LOGTO_PASSWORD` | PostgreSQL password for LogTo |
| `POSTGRES_MESHCOREHUB_USERNAME` | PostgreSQL user for MeshCore Hub (default: `meshcorehub`) |
| `POSTGRES_MESHCOREHUB_PASSWORD` | PostgreSQL password for MeshCore Hub |
| `B2_ENDPOINT`                       | Backblaze B2 S3 endpoint (e.g., `s3.us-east-005.backblazeb2.com`) |
| `B2_BUCKET_NAME`                    | B2 bucket name for backups                                        |
| `B2_ACCESS_KEY_ID`                  | B2 application key ID                                             |
| `B2_SECRET_ACCESS_KEY`              | B2 application key secret                                         |
| `HUB_API_READ_KEY`                  | Hub API key for Prometheus basic auth                             |
| `HUB_API_TARGET`                    | Hub API container target (default: `hub-prod-api:8000`)           |
| `DISCORD_WEBHOOK_URL`               | Discord webhook URL for Alertmanager alerts                       |
| `LOGTO_IMAGE_TAG`                   | LogTo Docker image tag (default: `latest`)                        |
| `LOGTO_PRIVATE_KEY_ROTATION_GRACE_PERIOD` | OIDC key rotation grace period in seconds (default: `3600`) |

### Per-Instance Variables (in each hub instance's `.env`)

| Variable               | Description                                       |
| ---------------------- | ------------------------------------------------- |
| `COMPOSE_PROJECT_NAME` | Unique project name (e.g., `hub-prod`, `hub-stg`) |
| `TRAEFIK_DOMAIN`       | Domain for this instance (e.g., `ipnt.uk`)        |
| `IMAGE_VERSION`        | Docker image tag (e.g., `v0.9.0`, `main`)         |
| `MQTT_HOST`            | Set to `mqtt` (shared broker container name)      |
| `CONTENT_HOME`         | Set to `../infrastructure/content`                |
| `SEED_HOME`            | Seed data directory path                          |

## Configuration Files

| File                                | Description                                                     |
| ----------------------------------- | --------------------------------------------------------------- |
| `docker-compose.yml`                | All infrastructure services (profile-gated, root of repo)       |
| `config/traefik/config.yml`         | Traefik static config (rate limiting)                          |
| `etc/prometheus/prometheus.yml`     | Prometheus scrape and alerting config                          |
| `etc/prometheus/rules/meshcore.yml` | Prometheus alert rules                                         |
| `etc/alertmanager/alertmanager.yml` | Alertmanager Discord routing config                            |
| `etc/postgres/init/`                | PostgreSQL init SQL scripts (run on first start)               |
| `scripts/bootstrap-instance.sh`     | Create a new hub instance directory                            |

## Security Notes

- All external traffic uses HTTPS with automatic certificate management
- MQTT broker requires subscriber authentication
- Rate limiting middleware available for Traefik routes
- Discord Alertmanager notifications do not support Markdown or emoji — use plain text only
