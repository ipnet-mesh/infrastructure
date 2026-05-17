# IPNet Mesh Infrastructure

[![Firmware Releases](https://github.com/ipnet-mesh/infrastructure/actions/workflows/firmware-releases.yml/badge.svg)](https://github.com/ipnet-mesh/infrastructure/actions/workflows/firmware-releases.yml)

Docker Compose-based infrastructure for hosting multiple MeshCore Hub instances behind a shared Traefik reverse proxy and MQTT broker.

## Architecture

All services connect to an external `proxy-net` Docker network. Infrastructure services (Traefik, MQTT) are managed here. Each MeshCore Hub instance is a separate independent compose stack.

```
                      Internet Users
                           │
                      HTTPS (443)
                   ┌────────▼─────────┐
                   │     Traefik      │
                   │  (Reverse Proxy) │
                   │  TLS/ACME via    │
                   │  Cloudflare DNS  │
                   └────────┬─────────┘
                            │
            ┌────────────────┼──────────────────┐
            │                │                  │
       ┌────▼─────┐   ┌──────▼──────┐   ┌──────▼──────┐
       │  MQTT    │   │ hub-prod/   │   │ hub-stg/    │
       │  Broker  │◄──│  collector  │   │  collector  │
       │(shared)  │◄──│  api        │   │  api        │
       └──────────┘   │  web        │   │  web        │
                      └──────┬──────┘   └─────────────┘
                             │
                    ┌────────▼─────────┐
                    │   Monitoring     │
                    │  Prometheus      │
                    │  Alertmanager    │
                    │  (Discord alerts)│
                    └──────────────────┘
            │                │                  │
            └────────────────┼──────────────────┘
                       proxy-net (external)
```

### Components

| Component         | Location             | Description                                                              |
| ----------------- | -------------------- | ------------------------------------------------------------------------ |
| **Traefik**       | `infrastructure/`    | Reverse proxy with automatic HTTPS via Cloudflare DNS challenge          |
| **PostgreSQL**    | `infrastructure/`    | Shared database server for all services on proxy-net                    |
| **MQTT Broker**   | `infrastructure/`    | Shared MeshCore MQTT Broker (WebSocket-only) for all hub instances       |
| **Volume Backup** | `infrastructure/`    | Daily volume snapshots to Backblaze B2 via `offen/docker-volume-backup`  |
| **Monitoring**    | `infrastructure/`    | Prometheus and Alertmanager scraping hub API metrics with Discord alerts |
| **LogTo**         | `infrastructure/`    | Self-hosted OIDC identity provider with admin console and core endpoint  |
| **Hub Instances** | Separate directories | Independent MeshCore Hub stacks (collector, API, web)                    |

### Shared Resources

- **TLS certificates** — Managed by Traefik via Let's Encrypt with Cloudflare DNS challenge
- **MQTT broker** — All hub instances connect to the same broker and ingest the same mesh traffic
- **Content** — `infrastructure/content/` mounted into each hub instance for shared pages and media
- **Volume backups** — Daily snapshots of `hub-prod_data`, `hub-stg_data`, `postgres_data`, and `prometheus_data` volumes to Backblaze B2 with 30-day retention
- **Identity provider** — LogTo provides OIDC authentication for all services at `auth.<domain>` with admin at `id.<domain>`

## Prerequisites

- Docker and Docker Compose v2
- Cloudflare account with DNS API access
- Domain configured to use Cloudflare DNS
- [MeshCore Hub](https://github.com/ipnet-mesh/meshcore-hub) compose files (wget'd via bootstrap script)

## Quick Start

### 1. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` with your settings:

```env
ROOT_DOMAIN=example.com
DNS_PROVIDER=cloudflare
DNS_API_EMAIL=your-email@example.com
DNS_API_TOKEN=your-cloudflare-dns-api-token
ACME_EMAIL=acme@example.com
TRAEFIK_HTTP_PORT=80
TRAEFIK_HTTPS_PORT=443
TRAEFIK_LOG_LEVEL=INFO
MQTT_PORT=1883
MQTT_USERNAME=mqttuser
MQTT_PASSWORD=generate-a-secure-password
MQTT_TOKEN_AUDIENCE=mqtt.example.com

# Backblaze B2 backup
B2_ENDPOINT=s3.us-east-005.backblazeb2.com
B2_BUCKET_NAME=my-backup-bucket
B2_ACCESS_KEY_ID=your-b2-key-id
B2_SECRET_ACCESS_KEY=your-b2-secret-key
```

### 2. Create Network and Volumes

```bash
docker network create proxy-net
docker volume create acme
docker volume create postgres_data
docker volume create prometheus_data
```

### 3. Start Infrastructure Services

```bash
# Start PostgreSQL
docker compose -f compose/postgres.yml up -d

# Start Traefik reverse proxy
docker compose -f compose/traefik.yml up -d

# Start shared MQTT broker
docker compose -f compose/mqtt.yml up -d

# Start volume backup
docker compose -f compose/backup.yml up -d

# Start monitoring (Prometheus & Alertmanager)
docker compose -f compose/monitoring.yml up -d

# Start LogTo identity provider
docker compose -f compose/logto.yml up -d
```

### 4. Verify

- Traefik dashboard: `http://localhost:8080`
- MQTT broker health: `docker compose -f compose/mqtt.yml logs mqtt`
- PostgreSQL health: `docker compose -f compose/postgres.yml logs postgres`

## Multi-Instance Setup

Each MeshCore Hub instance is a separate directory containing wget'd compose files and a local `.env`. Instances share the MQTT broker and content directory but have independent databases and configuration.

### Creating a New Instance

Use the bootstrap script to create a new hub instance:

```bash
# Production instance
./scripts/bootstrap-instance.sh ../hub-prod v0.9.0 example.com

# Staging instance
./scripts/bootstrap-instance.sh ../hub-stg main beta.example.com
```

This creates the instance directory with:

```
hub-prod/
├── docker-compose.yml            # Base services
├── docker-compose.prod.yml       # proxy-net network config
├── docker-compose.traefik.yml    # Traefik routing labels
├── docker-compose.dev.yml        # Dev port mappings (optional)
├── etc/
│   ├── prometheus/
│   │   ├── prometheus.yml
│   │   └── alerts.yml
│   └── alertmanager/
│       └── alertmanager.yml
└── .env                          # Instance configuration
```

Edit the instance's `.env` file. Key variables:

```env
# Instance identity
COMPOSE_PROJECT_NAME=hub-prod
TRAEFIK_DOMAIN=example.com
IMAGE_VERSION=v0.9.0

# Shared MQTT broker (container name on proxy-net)
MQTT_HOST=mqtt
MQTT_PORT=1883
MQTT_USERNAME=mqttuser
MQTT_PASSWORD=generate-a-secure-password
MQTT_TOKEN_AUDIENCE=mqtt.example.com

# Shared content from infrastructure repo
CONTENT_HOME=../infrastructure/content
```

Additional configuration (API keys, network name, feature flags, etc.) is documented in [MeshCore Hub's `.env.example`](https://github.com/ipnet-mesh/meshcore-hub/blob/main/.env.example).

### Starting an Instance

```bash
cd ../hub-prod

docker compose \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.traefik.yml \
  --profile core \
  up -d
```

### Multiple Instances

Each instance must have a unique `COMPOSE_PROJECT_NAME`. This prefixes all container names and Docker volumes, preventing conflicts:

| Instance   | `COMPOSE_PROJECT_NAME` | `TRAEFIK_DOMAIN` | `IMAGE_VERSION` | Monitoring                 |
| ---------- | ---------------------- | ---------------- | --------------- | -------------------------- |
| Production | `hub-prod`             | `ipnt.uk`        | `v0.9.0`        | Yes (infrastructure stack) |
| Staging    | `hub-stg`              | `beta.ipnt.uk`   | `main`          | No                         |

Both instances ingest the same MQTT messages into their own independent databases.

## Environment Variables

### Infrastructure Variables

These are set in `infrastructure/.env` and apply to Traefik and the shared MQTT broker.

| Variable                            | Description                                          | Default             |
| ----------------------------------- | ---------------------------------------------------- | ------------------- |
| `ROOT_DOMAIN`                       | Root domain for TLS certificates and MQTT routing    | Required            |
| `DNS_PROVIDER`                      | DNS provider for ACME DNS challenge                  | `cloudflare`        |
| `DNS_API_EMAIL`                     | Cloudflare account email                             | Required            |
| `DNS_API_TOKEN`                     | Cloudflare DNS API token                             | Required            |
| `ACME_EMAIL`                        | Email for Let's Encrypt certificates                 | Required            |
| `TRAEFIK_HTTP_PORT`                 | Host port for HTTP (redirects to HTTPS)              | `80`                |
| `TRAEFIK_HTTPS_PORT`                | Host port for HTTPS                                  | `443`               |
| `TRAEFIK_LOG_LEVEL`                 | Traefik log level (`DEBUG`, `INFO`, `WARN`, `ERROR`) | `INFO`              |
| `MQTT_PORT`                         | MQTT WebSocket port (container)                      | `1883`              |
| `MQTT_USERNAME`                     | MQTT subscriber username                             | Required            |
| `MQTT_PASSWORD`                     | MQTT subscriber password                             | Required            |
| `MQTT_TOKEN_AUDIENCE`               | JWT audience for authentication tokens               | `mqtt.localhost`    |
| `POSTGRES_IMAGE_TAG`                | PostgreSQL Docker image tag                          | `17-alpine`         |
| `POSTGRES_USER`                     | PostgreSQL superuser username                        | Required            |
| `POSTGRES_PASSWORD`                 | PostgreSQL superuser password                        | Required            |
| `B2_ENDPOINT`                       | Backblaze B2 S3-compatible endpoint                  | Required            |
| `B2_BUCKET_NAME`                    | B2 bucket name for volume backups                    | Required            |
| `B2_ACCESS_KEY_ID`                  | B2 application key ID                                | Required            |
| `B2_SECRET_ACCESS_KEY`              | B2 application key secret                            | Required            |
| `HUB_API_READ_KEY`                  | Hub API key for Prometheus basic auth                | Required            |
| `HUB_API_TARGET`                    | Hub API container target for Prometheus              | `hub-prod-api:8000` |
| `DISCORD_WEBHOOK_URL`               | Discord webhook URL for Alertmanager alerts          | Required            |
| `LOGTO_IMAGE_TAG`                   | LogTo Docker image tag                               | `latest`            |
| `POSTGRES_LOGTO_USERNAME`           | PostgreSQL user for LogTo                            | `logto`             |
| `POSTGRES_LOGTO_PASSWORD`           | PostgreSQL password for LogTo                        | Required            |
| `PRIVATE_KEY_ROTATION_GRACE_PERIOD` | OIDC key rotation grace period (seconds)             | `3600`              |

### Per-Instance Variables

These are set in each hub instance's `.env`. See [MeshCore Hub's `.env.example`](https://github.com/ipnet-mesh/meshcore-hub/blob/main/.env.example) for the full list.

| Variable               | Description                                          | Example                     |
| ---------------------- | ---------------------------------------------------- | --------------------------- |
| `COMPOSE_PROJECT_NAME` | Unique project name (prefixes containers/volumes)    | `hub-prod`                  |
| `TRAEFIK_DOMAIN`       | Domain for Traefik routing                           | `ipnt.uk`                   |
| `IMAGE_VERSION`        | Docker image tag                                     | `v0.9.0` or `main`          |
| `MQTT_HOST`            | MQTT broker hostname (use `mqtt` for shared broker)  | `mqtt`                      |
| `MQTT_PORT`            | MQTT broker port                                     | `1883`                      |
| `MQTT_USERNAME`        | MQTT subscriber username (must match infrastructure) | `mqttuser`                  |
| `MQTT_PASSWORD`        | MQTT subscriber password (must match infrastructure) |                             |
| `MQTT_TOKEN_AUDIENCE`  | JWT audience (must match infrastructure)             | `mqtt.example.com`          |
| `CONTENT_HOME`         | Path to shared content directory                     | `../infrastructure/content` |
| `SEED_HOME`            | Path to seed data directory                          | `./seed`                    |

## Operational Commands

### Infrastructure

```bash
# Start services
docker compose -f compose/traefik.yml up -d
docker compose -f compose/mqtt.yml up -d
docker compose -f compose/postgres.yml up -d
docker compose -f compose/backup.yml up -d
docker compose -f compose/monitoring.yml up -d
docker compose -f compose/logto.yml up -d

# Stop services
docker compose -f compose/traefik.yml down
docker compose -f compose/mqtt.yml down
docker compose -f compose/postgres.yml down
docker compose -f compose/backup.yml down
docker compose -f compose/monitoring.yml down
docker compose -f compose/logto.yml down

# View logs
docker compose -f compose/traefik.yml logs -f
docker compose -f compose/mqtt.yml logs -f
docker compose -f compose/postgres.yml logs -f
docker compose -f compose/backup.yml logs -f
docker compose -f compose/monitoring.yml logs -f
docker compose -f compose/logto.yml logs -f

# Trigger a manual backup
docker compose -f compose/backup.yml exec backup backup
```

### Hub Instances

```bash
cd ../hub-prod

# Start
docker compose -f docker-compose.yml -f docker-compose.prod.yml \
  -f docker-compose.traefik.yml --profile core up -d

# Stop
docker compose -f docker-compose.yml -f docker-compose.prod.yml \
  -f docker-compose.traefik.yml down

# View logs
docker compose -f docker-compose.yml -f docker-compose.prod.yml logs -f

# Run database migrations
docker compose -f docker-compose.yml -f docker-compose.prod.yml \
  --profile migrate up db-migrate

# Import seed data
docker compose -f docker-compose.yml -f docker-compose.prod.yml \
  --profile seed up seed
```

## Directory Structure

```
infrastructure/
├── compose/
│   ├── traefik.yml              # Traefik reverse proxy
│   ├── mqtt.yml                 # Shared MeshCore MQTT broker
│   ├── postgres.yml             # PostgreSQL database server
│   ├── monitoring.yml           # Prometheus and Alertmanager
│   ├── logto.yml                # LogTo identity provider
│   └── backup.yml               # Volume backup to Backblaze B2
├── config/
│   └── traefik/
│       └── config.yml           # Traefik static config (rate limiting)
├── content/                     # Shared content (mounted by hub instances)
│   ├── prod/                    # Production content
│   │   ├── media/
│   │   └── pages/
│   ├── stg/                     # Staging content
│   │   ├── media/
│   │   └── pages/
│   └── dev/                     # Development content
│       ├── media/
│       └── pages/
├── etc/
│   ├── postgres/
│   │   └── init/                # Init SQL scripts (run on first start)
│   ├── prometheus/
│   │   ├── prometheus.yml
│   │   └── rules/
│   └── alertmanager/
│       └── alertmanager.yml
├── scripts/
│   └── bootstrap-instance.sh    # Create a new hub instance directory
├── .env                         # Infrastructure configuration
└── .env.example                 # Template for .env
```

## Security Notes

- All external traffic uses HTTPS with automatic Let's Encrypt certificates
- MQTT broker requires subscriber authentication with role-based access
- Rate limiting middleware available for Traefik routes
- No ports are exposed directly on hub instances — all traffic goes through Traefik
- Discord Alertmanager notifications do not support Markdown or emoji — use plain text only
