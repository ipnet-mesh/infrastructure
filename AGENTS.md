# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the infrastructure repository for IPNet Mesh - a Docker Compose-based infrastructure setup that provides:
- Traefik reverse proxy with automatic HTTPS via Cloudflare DNS challenges
- OAuth2 Proxy for GitHub-based authentication on protected routes
- Eclipse Mosquitto MQTT broker with WebSocket support
- MeshCore Hub services (API, Web, Collector) for both production and staging environments

## Architecture

The infrastructure runs from a single `docker-compose.yml` at the repository root. All services share an external `proxy` network for Traefik routing.

### Services

- **Traefik**: Reverse proxy and TLS termination
  - Automatic HTTPS via Let's Encrypt with Cloudflare DNS challenge
  - Dynamic routing based on Docker labels
  - Ports: 80 (HTTP→HTTPS redirect), 443 (HTTPS), 8883 (MQTTS)

- **OAuth2 Proxy** (prod & stg): Authentication reverse proxy
  - Uses GitHub OAuth for user authentication
  - Protects `/admin` routes
  - Separate instances for production and staging

- **Mosquitto**: MQTT message broker
  - Authentication required (no anonymous access)
  - Native MQTT port 1883 (internal only)
  - WebSocket on port 8080 (exposed via Traefik at `/mqtt`)
  - ACL-based topic access control

- **Hub Services** (prod & stg):
  - `hub-collector`: MQTT message processor
  - `hub-api`: REST API backend
  - `hub-web`: Web frontend

## Environments

| Environment | Domain Pattern | Image Tag | Description |
|-------------|----------------|-----------|-------------|
| Production | `ipnt.uk`, `*.ipnt.uk` | `latest` | Stable releases |
| Staging | `beta.ipnt.uk`, `*.beta.ipnt.uk` | `main` | Development branch |

## Traefik Routing Priority

Higher priority values are evaluated first:

| Priority | Route | Description |
|----------|-------|-------------|
| 100 | `/oauth2/*` | OAuth2 callbacks (critical for auth flow) |
| 100 | `api.*`, `mqtt.*` | API and MQTT endpoints |
| 60 | `beta.*/admin` | Staging admin panel |
| 50 | `beta.*` | Staging website |
| 20 | `*/admin` | Production admin panel |
| 10 | `*` | Production website (catch-all) |

## Common Development Commands

### Starting/Managing Services

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# View logs
docker compose logs -f [service-name]

# Restart a specific service
docker compose restart [service-name]
```

### Network and Volume Setup

```bash
# Create required network and volume (first time only)
docker network create proxy
docker volume create acme
```

## Environment Variables

Copy `.env.example` to `.env` and configure:

### Required Variables

| Variable | Description |
|----------|-------------|
| `ROOT_DOMAIN` | Root domain (e.g., `ipnt.uk`) |
| `DNS_PROVIDER` | DNS provider for ACME (e.g., `cloudflare`) |
| `DNS_API_EMAIL` | Cloudflare account email |
| `DNS_API_TOKEN` | Cloudflare DNS API token |
| `ACME_EMAIL` | Email for Let's Encrypt certificates |

### OAuth2 Proxy Variables

| Variable | Description |
|----------|-------------|
| `OAUTH2_PROXY_CLIENT_ID` | GitHub OAuth App Client ID |
| `OAUTH2_PROXY_CLIENT_SECRET` | GitHub OAuth App Client Secret |
| `OAUTH2_PROXY_COOKIE_SECRET` | 32-byte base64-encoded secret |
| `OAUTH2_PROXY_GITHUB_ORG` | (Optional) Restrict to GitHub org members |
| `OAUTH2_PROXY_GITHUB_USERS` | (Optional) Comma-separated allowed usernames |

### Hub Variables

| Variable | Description |
|----------|-------------|
| `HUB_DATA_HOME` | Data directory path |
| `HUB_SEED_HOME` | Seed data directory path |
| `HUB_LOG_LEVEL` | Logging level (INFO, DEBUG, etc.) |
| `HUB_API_READ_KEY` | API read access key |
| `HUB_API_ADMIN_KEY` | API admin access key |
| `MQTT_USERNAME` | MQTT broker username |
| `MQTT_PASSWORD` | MQTT broker password |

## Configuration Files

| File | Description |
|------|-------------|
| `docker-compose.yml` | Main service definitions |
| `config/traefik/config.yml` | Traefik middleware (rate limiting) |
| `config/mosquitto/mosquitto.conf` | MQTT broker configuration |
| `config/mosquitto/acl.conf` | MQTT topic access control (copy from `.example`) |
| `config/mosquitto/passwd` | MQTT user credentials (copy from `.example`) |

## OAuth2 Proxy Authentication Flow

1. User requests protected route (e.g., `/admin`)
2. OAuth2 Proxy redirects to GitHub OAuth
3. User authenticates with GitHub
4. GitHub redirects to `/oauth2/callback` (priority 100)
5. OAuth2 Proxy sets session cookie (domain-wide: `.${ROOT_DOMAIN}`)
6. User redirected to original URL

## Security Notes

- All external traffic uses HTTPS with automatic certificate management
- OAuth2 Proxy protects admin routes with GitHub authentication
- Mosquitto requires authentication (users defined in passwd file)
- MQTT supports TLS (port 8883) and WebSocket over HTTPS
- Rate limiting middleware available for Traefik routes
- Cookies are secure (HTTPS-only) and shared across subdomains
