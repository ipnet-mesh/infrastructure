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
