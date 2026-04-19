# IPNet Mesh Infrastructure

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
                    │  prometheus │   └─────────────┘
                    └─────────────┘
          │                │                  │
          └────────────────┼──────────────────┘
                     proxy-net (external)
```

### Components

| Component | Location | Description |
|-----------|----------|-------------|
| **Traefik** | `infrastructure/` | Reverse proxy with automatic HTTPS via Cloudflare DNS challenge |
| **MQTT Broker** | `infrastructure/` | Shared MeshCore MQTT Broker (WebSocket-only) for all hub instances |
| **Hub Instances** | Separate directories | Independent MeshCore Hub stacks (collector, API, web, optional monitoring) |

### Shared Resources

- **TLS certificates** — Managed by Traefik via Let's Encrypt with Cloudflare DNS challenge
- **MQTT broker** — All hub instances connect to the same broker and ingest the same mesh traffic
- **Content** — `infrastructure/content/` mounted into each hub instance for shared pages and media

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
```

### 2. Create Network and Volumes

```bash
docker network create proxy-net
docker volume create acme
```

### 3. Start Infrastructure Services

```bash
# Start Traefik reverse proxy
docker compose -f compose/traefik.yml up -d

# Start shared MQTT broker
docker compose -f compose/mqtt.yml up -d
```

### 4. Verify

- Traefik dashboard: `http://localhost:8080`
- MQTT broker health: `docker compose -f compose/mqtt.yml logs mqtt`

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

### Configuring an Instance

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

# With monitoring (Prometheus + Alertmanager)
docker compose \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.traefik.yml \
  --profile core \
  --profile metrics \
  up -d

# Without monitoring
docker compose \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.traefik.yml \
  --profile core \
  up -d
```

### Multiple Instances

Each instance must have a unique `COMPOSE_PROJECT_NAME`. This prefixes all container names and Docker volumes, preventing conflicts:

| Instance | `COMPOSE_PROJECT_NAME` | `TRAEFIK_DOMAIN` | `IMAGE_VERSION` | Monitoring |
|----------|------------------------|------------------|-----------------|------------|
| Production | `hub-prod` | `ipnt.uk` | `v0.9.0` | Yes |
| Staging | `hub-stg` | `beta.ipnt.uk` | `main` | No |

Both instances ingest the same MQTT messages into their own independent databases.

## Environment Variables

### Infrastructure Variables

These are set in `infrastructure/.env` and apply to Traefik and the shared MQTT broker.

| Variable | Description | Default |
|----------|-------------|---------|
| `ROOT_DOMAIN` | Root domain for TLS certificates and MQTT routing | Required |
| `DNS_PROVIDER` | DNS provider for ACME DNS challenge | `cloudflare` |
| `DNS_API_EMAIL` | Cloudflare account email | Required |
| `DNS_API_TOKEN` | Cloudflare DNS API token | Required |
| `ACME_EMAIL` | Email for Let's Encrypt certificates | Required |
| `TRAEFIK_HTTP_PORT` | Host port for HTTP (redirects to HTTPS) | `80` |
| `TRAEFIK_HTTPS_PORT` | Host port for HTTPS | `443` |
| `TRAEFIK_LOG_LEVEL` | Traefik log level (`DEBUG`, `INFO`, `WARN`, `ERROR`) | `INFO` |
| `MQTT_PORT` | MQTT WebSocket port (container) | `1883` |
| `MQTT_USERNAME` | MQTT subscriber username | Required |
| `MQTT_PASSWORD` | MQTT subscriber password | Required |
| `MQTT_TOKEN_AUDIENCE` | JWT audience for authentication tokens | `mqtt.localhost` |

### Per-Instance Variables

These are set in each hub instance's `.env`. See [MeshCore Hub's `.env.example`](https://github.com/ipnet-mesh/meshcore-hub/blob/main/.env.example) for the full list.

| Variable | Description | Example |
|----------|-------------|---------|
| `COMPOSE_PROJECT_NAME` | Unique project name (prefixes containers/volumes) | `hub-prod` |
| `TRAEFIK_DOMAIN` | Domain for Traefik routing | `ipnt.uk` |
| `IMAGE_VERSION` | Docker image tag | `v0.9.0` or `main` |
| `MQTT_HOST` | MQTT broker hostname (use `mqtt` for shared broker) | `mqtt` |
| `MQTT_PORT` | MQTT broker port | `1883` |
| `MQTT_USERNAME` | MQTT subscriber username (must match infrastructure) | `mqttuser` |
| `MQTT_PASSWORD` | MQTT subscriber password (must match infrastructure) | |
| `MQTT_TOKEN_AUDIENCE` | JWT audience (must match infrastructure) | `mqtt.example.com` |
| `CONTENT_HOME` | Path to shared content directory | `../infrastructure/content` |
| `SEED_HOME` | Path to seed data directory | `./seed` |

## Operational Commands

### Infrastructure

```bash
# Start services
docker compose -f compose/traefik.yml up -d
docker compose -f compose/mqtt.yml up -d

# Stop services
docker compose -f compose/traefik.yml down
docker compose -f compose/mqtt.yml down

# View logs
docker compose -f compose/traefik.yml logs -f
docker compose -f compose/mqtt.yml logs -f
```

### Hub Instances

```bash
cd ../hub-prod

# Start (with monitoring)
docker compose -f docker-compose.yml -f docker-compose.prod.yml \
  -f docker-compose.traefik.yml --profile core --profile metrics up -d

# Start (without monitoring)
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
│   └── mqtt.yml                 # Shared MeshCore MQTT broker
├── config/
│   └── traefik/
│       └── config.yml           # Traefik static config (rate limiting)
├── content/                     # Shared content (mounted by hub instances)
│   ├── media/
│   └── pages/
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
