# IPNet Mesh Infrastructure

[![MQTT Post: Daily Advert](https://github.com/ipnet-mesh/infrastructure/actions/workflows/mqtt-post-advert.yml/badge.svg)](https://github.com/ipnet-mesh/infrastructure/actions/workflows/mqtt-post-advert.yml)
[![MQTT Post: Daily Briefing](https://github.com/ipnet-mesh/infrastructure/actions/workflows/mqtt-post-weather.yml/badge.svg)](https://github.com/ipnet-mesh/infrastructure/actions/workflows/mqtt-post-weather.yml)

Docker Compose-based infrastructure for the IPNet Mesh network, providing reverse proxy, MQTT messaging, and web services.

## Overview

This repository contains the containerized infrastructure components for IPNet Mesh:

- **Pangolin**: Reverse proxy , load balancer and authorisation platform with automatic HTTPS
- **Mosquitto**: MQTT message broker with WebSocket support
- **Website**: IPNet Mesh web application

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Cloudflare account with DNS API access
- Domain configured to use Cloudflare DNS

### Initial Setup

Configure environment variables for Traefik:
```bash
export CF_API_EMAIL="your-cloudflare-email@example.com"
export CF_DNS_API_TOKEN="your-cloudflare-dns-token"
export ACME_EMAIL="your-email@example.com"
```

Set up Mosquitto authentication:
```bash
cd docker/compose/mosquitto/config
cp acl.conf.example acl.conf
cp passwd.example passwd
# Edit passwd file with your MQTT users
```

### Starting Services

```bash
# Start Mosquitto (MQTT broker)
cd ../mosquitto
docker compose up -d

# Start Website
cd ../website
docker compose up -d
```

### Stopping Services

```bash
# Stop all services
cd docker/compose/mosquitto && docker compose down
cd docker/compose/website && docker compose down
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

## Development

### Viewing Logs

```bash
# View logs for a specific service
cd docker/compose/[service]
docker compose logs -f

# View logs for all containers
docker compose logs -f [service-name]
```

### Updating Services

```bash
# Pull latest images and restart
cd docker/compose/[service]
docker compose pull
docker compose up -d
```

## Troubleshooting

### Certificate Issues
- Check Cloudflare API credentials
- Verify domain DNS is using Cloudflare
- Check Traefik logs: `docker compose logs traefik`

### MQTT Connection Issues
- Verify user credentials in `passwd` file
- Check ACL permissions in `acl.conf`
- Test connectivity: `mosquitto_pub -h mqtt.ipnt.uk -p 8883 -u username -P password -t test -m "hello"`
