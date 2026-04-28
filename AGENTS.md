# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the infrastructure repository for IPNet Mesh — a Docker Compose-based setup providing:

- **Traefik** reverse proxy with automatic HTTPS via Cloudflare DNS challenges
- **PostgreSQL** database server shared across services
- **MeshCore MQTT Broker** shared across all hub instances
- **Prometheus & Alertmanager** monitoring hub API metrics with Discord alerts
- **Volume Backup** to Backblaze B2 via `offen/docker-volume-backup`

Hub instances (MeshCore Hub) are deployed as separate independent compose stacks, each started from their own directory with wget'd compose files and a local `.env`.

## Architecture

All services connect to an external `proxy-net` Docker network. Each stack is started independently.

```
infrastructure/                hub-prod/              hub-stg/
├── compose/                   ├── docker-compose.*   ├── docker-compose.*
│   ├── traefik.yml            ├── etc/               ├── etc/
│   ├── mqtt.yml               └── .env               └── .env
│   ├── postgres.yml
│   ├── monitoring.yml
│   └── backup.yml
├── config/
├── content/  ← shared volume
└── .env
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
  - Data stored in `postgres_data` volume (included in daily backups)

- **Backup**: Volume backup to Backblaze B2 (via `offen/docker-volume-backup`)
  - Daily snapshots of `hub-prod_data`, `hub-stg_data`, and `postgres_data` volumes
  - 30-day retention with automatic pruning
  - S3-compatible B2 endpoint

- **Monitoring**: Prometheus and Alertmanager
  - Prometheus scrapes hub API `/metrics` endpoint
  - Alertmanager routes alerts to Discord via Slack-compatible webhook
  - Exposed at `metrics.<domain>` and `alerts.<domain>` via Traefik
  - Scrape target configurable via `HUB_API_TARGET` (default: `hub-prod-api:8000`)

- **Hub Instances**: Independent MeshCore Hub stacks (collector, API, web)
  - Each has its own `.env` with unique `COMPOSE_PROJECT_NAME`
  - Storage via Docker volumes (namespaced per project)
  - Traefik labels for routing (via `docker-compose.traefik.yml`)
  - Content mounted from `../infrastructure/content`

## Environments

| Environment | Domain Pattern | Image Tag | Monitoring |
|-------------|----------------|-----------|------------|
| Production | `ipnt.uk`, `*.ipnt.uk` | `v0.9.0` | Yes (infrastructure stack) |
| Staging | `beta.ipnt.uk`, `*.beta.ipnt.uk` | `main` | No |

## Common Development Commands

### Infrastructure Services

```bash
# Start Traefik
docker compose -f compose/traefik.yml up -d

# Start MQTT broker
docker compose -f compose/mqtt.yml up -d

# Start volume backup
docker compose -f compose/backup.yml up -d

# Start monitoring (Prometheus & Alertmanager)
docker compose -f compose/monitoring.yml up -d

# Stop a service
docker compose -f compose/traefik.yml down
docker compose -f compose/mqtt.yml down
docker compose -f compose/backup.yml down
docker compose -f compose/monitoring.yml down

# View logs
docker compose -f compose/traefik.yml logs -f
docker compose -f compose/mqtt.yml logs -f
docker compose -f compose/postgres.yml logs -f
docker compose -f compose/backup.yml logs -f
docker compose -f compose/monitoring.yml logs -f
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
docker volume create acme
docker volume create postgres_data
```

## Environment Variables

Copy `.env.example` to `.env` and configure:

### Infrastructure Variables

| Variable | Description |
|----------|-------------|
| `ROOT_DOMAIN` | Root domain (e.g., `ipnt.uk`) |
| `DNS_PROVIDER` | DNS provider for ACME (e.g., `cloudflare`) |
| `DNS_API_EMAIL` | Cloudflare account email |
| `DNS_API_TOKEN` | Cloudflare DNS API token |
| `ACME_EMAIL` | Email for Let's Encrypt certificates |
| `TRAEFIK_HTTP_PORT` | Host port for HTTP (default: `80`) |
| `TRAEFIK_HTTPS_PORT` | Host port for HTTPS (default: `443`) |
| `TRAEFIK_LOG_LEVEL` | Traefik log level (default: `INFO`) |
| `MQTT_PORT` | MQTT WebSocket port (default: `1883`) |
| `MQTT_USERNAME` | MQTT subscriber username |
| `MQTT_PASSWORD` | MQTT subscriber password |
| `MQTT_TOKEN_AUDIENCE` | JWT audience for auth tokens |
| `B2_ENDPOINT` | Backblaze B2 S3 endpoint (e.g., `s3.us-east-005.backblazeb2.com`) |
| `B2_BUCKET_NAME` | B2 bucket name for backups |
| `B2_ACCESS_KEY_ID` | B2 application key ID |
| `B2_SECRET_ACCESS_KEY` | B2 application key secret |
| `HUB_API_READ_KEY` | Hub API key for Prometheus basic auth |
| `HUB_API_TARGET` | Hub API container target (default: `hub-prod-api:8000`) |
| `DISCORD_WEBHOOK_URL` | Discord webhook URL for Alertmanager alerts |

### Per-Instance Variables (in each hub instance's `.env`)

| Variable | Description |
|----------|-------------|
| `COMPOSE_PROJECT_NAME` | Unique project name (e.g., `hub-prod`, `hub-stg`) |
| `TRAEFIK_DOMAIN` | Domain for this instance (e.g., `ipnt.uk`) |
| `IMAGE_VERSION` | Docker image tag (e.g., `v0.9.0`, `main`) |
| `MQTT_HOST` | Set to `mqtt` (shared broker container name) |
| `CONTENT_HOME` | Set to `../infrastructure/content` |
| `SEED_HOME` | Seed data directory path |

## Configuration Files

| File | Description |
|------|-------------|
| `compose/traefik.yml` | Traefik service definition |
| `compose/mqtt.yml` | MQTT broker service definition |
| `compose/postgres.yml` | PostgreSQL database server |
| `compose/monitoring.yml` | Prometheus and Alertmanager |
| `compose/backup.yml` | Volume backup to Backblaze B2 |
| `config/traefik/config.yml` | Traefik static config (rate limiting) |
| `etc/prometheus/prometheus.yml` | Prometheus scrape and alerting config |
| `etc/prometheus/rules/meshcore.yml` | Prometheus alert rules |
| `etc/alertmanager/alertmanager.yml` | Alertmanager Discord routing config |
| `scripts/bootstrap-instance.sh` | Create a new hub instance directory |

## Security Notes

- All external traffic uses HTTPS with automatic certificate management
- MQTT broker requires subscriber authentication
- Rate limiting middleware available for Traefik routes
- Discord Alertmanager notifications do not support Markdown or emoji — use plain text only
