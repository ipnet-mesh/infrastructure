# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the infrastructure repository for IPNet Mesh - a Docker Compose-based infrastructure setup that provides:
- Traefik reverse proxy with automatic HTTPS via Cloudflare DNS challenges
- Eclipse Mosquitto MQTT broker with WebSocket support
- Website deployment using container images from ghcr.io/ipnet-mesh/website

## Architecture

The infrastructure is organized into separate Docker Compose services in `docker/compose/`:

- **Mosquitto** (`docker/compose/mosquitto/`): MQTT message broker
  - Configured for authentication (no anonymous access)
  - Supports both native MQTT (port 1883, internal) and WebSocket (port 8080)
  - Uses ACL for topic-based access control

- **Website** (`docker/compose/website/`): Flask-based web application
  - Deployed from pre-built container images
  - Serves content at `beta.ipnt.uk`

All services use an external `proxy` network to communicate through Traefik.

## Common Development Commands

### Starting/Managing Services

Start all services:
```bash
cd docker/compose/mosquitto && docker compose up -d
cd docker/compose/website && docker compose up -d
```

Stop all services:
```bash
cd docker/compose/mosquitto && docker compose down
cd docker/compose/website && docker compose down
```

View logs:
```bash
cd docker/compose/[service] && docker compose logs -f
```

### Network Setup

### Environment Variables

Traefik requires these environment variables:
- `CF_API_EMAIL`: Cloudflare account email
- `CF_DNS_API_TOKEN`: Cloudflare DNS API token
- `ACME_EMAIL`: Email for Let's Encrypt certificates

### Configuration Files

- **Mosquitto config**: `docker/compose/mosquitto/config/mosquitto.conf`
- **Mosquitto ACL**: `docker/compose/mosquitto/config/acl.conf` (copy from .example)
- **Mosquitto passwords**: `docker/compose/mosquitto/config/passwd` (copy from .example)

## Domain Configuration

Services are configured for the `ipnt.uk` domain:
- Main website: `ipnt.uk`, `beta.ipnt.uk`, `alpha.ipnt.uk`
- MQTT broker: `mqtt.ipnt.uk` (both TLS and WebSocket)

## Security Notes

- Mosquitto requires authentication (users defined in passwd file)
- All external traffic goes through HTTPS with automatic certificate management
- MQTT supports both secure TLS connections and WebSocket over HTTPS
