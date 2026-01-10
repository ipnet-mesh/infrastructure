# IPNet Mesh Infrastructure

Docker Compose-based infrastructure for the IPNet Mesh network, providing reverse proxy, MQTT messaging, and web services.

## Overview

This repository contains the containerized infrastructure components for IPNet Mesh:

- **Traefik**: Reverse proxy , load balancer and authorisation platform with automatic HTTPS
- **Mosquitto**: MQTT message broker with WebSocket support
- **Hub Backend**: MeshCore Hub Collector, API and Web frontend

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Cloudflare account with DNS API access
- Domain configured to use Cloudflare DNS

### Initial Setup

Configure environment variables for Traefik:
```bash
export ROOT_DOMAIN="ipnt.uk"
export CF_API_EMAIL="your-cloudflare-email@example.com"
export CF_DNS_API_TOKEN="your-cloudflare-dns-token"
export ACME_EMAIL="your-email@example.com"
```

Set up Mosquitto authentication:
```bash
cd 
cp config/mosquitto/acl.conf.example config/mosquitto/acl.conf
cp config/mosquitto/passwd.example config/mosquitto/passwd
# Edit passwd file with your MQTT users
```

### Create Docker Networks & Volumes

```bash
docker network create proxy
docker volume create acme
```

### Starting Services

```bash
# Start all services
docker compose up -d
```

### Stopping Services

```bash
# Stop all services
docker compose down
```

## Configuration

### Domains

The infrastructure is configured for these domains:
- **Website**: `ipnt.uk`, `beta.ipnt.uk`, `alpha.ipnt.uk`
- **MQTT**: `mqtt.ipnt.uk`

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `CF_API_EMAIL` | Cloudflare account email | Yes |
| `CF_DNS_API_TOKEN` | Cloudflare DNS API token | Yes |
| `ACME_EMAIL` | Email for Let's Encrypt certificates | Yes |

### MQTT Configuration

- **Host**: `mqtt.ipnt.uk`
- **TLS Port**: 8883 (MQTT over TLS)
- **WebSocket URL**: `wss://mqtt.ipnt.uk/mqtt`
- **Authentication**: Required (configured in `passwd` file)

## Environments

The infrastructure supports two environments that run on the same host:

| Environment | Domain Pattern | Hub Image Tag | Purpose |
|-------------|----------------|---------------|---------|
| **Production** | `ipnt.uk`, `*.ipnt.uk` | `latest` | Stable releases |
| **Staging** | `beta.ipnt.uk`, `*.beta.ipnt.uk` | `main` | Development/testing |

Both environments share:
- The same Traefik reverse proxy
- The same MQTT broker
- The same TLS certificates
- OAuth2 authentication

## Traefik Configuration

### TLS/ACME Setup

Traefik handles TLS termination and automatic certificate management:

- **Certificate Resolver**: Let's Encrypt with Cloudflare DNS challenge
- **DNS Provider**: Cloudflare (supports wildcard certificates)
- **Auto-redirect**: HTTP (port 80) automatically redirects to HTTPS (port 443)
- **Certificate Storage**: External Docker volume (`acme`)

```yaml
# Key ACME configuration
certificatesresolvers.default.acme.dnschallenge=true
certificatesresolvers.default.acme.dnschallenge.provider=cloudflare
certificatesresolvers.default.acme.email=${ACME_EMAIL}
```

### Domain Routing Priority

Traefik uses priority values to determine which route handles a request. Higher priority routes are evaluated first:

| Priority | Service | Domain Pattern | Path | Description |
|----------|---------|----------------|------|-------------|
| 100 | oauth2-proxy-*-auth | `*.domain` | `/oauth2` | OAuth2 callbacks (must succeed) |
| 100 | hub-api-prod | `api.domain` | `/` | Production API |
| 100 | hub-api-stg | `api.beta.domain` | `/` | Staging API |
| 100 | mqtt-ws | `mqtt.domain` | `/mqtt` | MQTT WebSocket |
| 60 | oauth2-proxy-stg | `beta.domain` | `/admin` | Staging admin panel |
| 50 | hub-web-stg | `beta.domain` | `/` | Staging website |
| 20 | oauth2-proxy-prod | `*.domain` | `/admin` | Production admin panel |
| 10 | hub-web-prod | `*.domain` | `/` | Production website (fallback) |

**Key Principles**:
- OAuth2 callbacks have highest priority to ensure authentication flows complete
- API routes have high priority to prevent catch-all routes intercepting them
- Staging routes (`beta.*`) have higher priority than production wildcards
- Production website is the lowest priority catch-all

### Middleware

Rate limiting middleware is configured in `config/traefik/config.yml`:

```yaml
http:
  middlewares:
    rate-limit:
      rateLimit:
        burst: 10
        period: 1m
        average: 100
```

## OAuth2 Proxy Authentication

OAuth2 Proxy provides authentication for protected routes (e.g., `/admin`) using GitHub OAuth.

### How It Works

1. User requests a protected path (e.g., `/admin`)
2. OAuth2 Proxy intercepts and redirects to GitHub OAuth
3. User authenticates with their GitHub account
4. GitHub returns token to `/oauth2/callback`
5. OAuth2 Proxy validates and sets a session cookie
6. User is redirected to the original requested URL

### Configuration

| Variable | Description |
|----------|-------------|
| `OAUTH2_PROXY_CLIENT_ID` | GitHub OAuth App Client ID |
| `OAUTH2_PROXY_CLIENT_SECRET` | GitHub OAuth App Client Secret |
| `OAUTH2_PROXY_COOKIE_SECRET` | Random 32-byte base64-encoded secret |
| `OAUTH2_PROXY_GITHUB_ORG` | (Optional) Restrict access to GitHub org members |
| `OAUTH2_PROXY_GITHUB_USERS` | (Optional) Comma-separated list of allowed GitHub usernames |

### Creating a GitHub OAuth App

1. Go to GitHub Settings → Developer Settings → OAuth Apps → New OAuth App
2. Configure:
   - **Application name**: Your app name
   - **Homepage URL**: `https://yourdomain.com`
   - **Authorization callback URL**: `https://yourdomain.com/oauth2/callback`
3. Copy the Client ID and generate a Client Secret
4. Generate a cookie secret: `openssl rand -base64 32`

### Cookie Configuration

OAuth2 Proxy cookies are configured for domain-wide sharing:

- **Cookie Domain**: `.${ROOT_DOMAIN}` (shared across subdomains)
- **Cookie Secure**: `true` (HTTPS only)
- **Cookie Name**: `_oauth2_proxy`

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Internet Users                          │
└────────────────────────────┬────────────────────────────────┘
                             │ HTTPS (443) / MQTTS (8883)
                    ┌────────▼─────────┐
                    │     Traefik      │
                    │  (Reverse Proxy) │
                    │  TLS/ACME via    │
                    │  Cloudflare DNS  │
                    └────────┬─────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
   ┌────▼─────┐      ┌───────▼───────┐      ┌─────▼──────┐
   │OAuth2    │      │   Hub API     │      │  Mosquitto │
   │Proxy     │      │  (prod/stg)   │      │    MQTT    │
   │(prod/stg)│      └───────────────┘      └────────────┘
   └────┬─────┘
        │
   ┌────▼─────┐
   │  Hub Web │
   │(prod/stg)│
   └──────────┘
```
