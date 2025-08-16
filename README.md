# IPNet Mesh Infrastructure

[![MQTT Post: Daily](https://github.com/ipnet-mesh/infrastructure/actions/workflows/daily-mqtt-publish.yml/badge.svg)](https://github.com/ipnet-mesh/infrastructure/actions/workflows/daily-mqtt-publish.yml)

Docker Compose-based infrastructure for the IPNet Mesh network, providing reverse proxy, MQTT messaging, and web services.

## Overview

This repository contains the containerized infrastructure components for IPNet Mesh:

- **Traefik**: Reverse proxy and load balancer with automatic HTTPS
- **Mosquitto**: MQTT message broker with WebSocket support
- **Website**: IPNet Mesh web application

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Cloudflare account with DNS API access
- Domain configured to use Cloudflare DNS

### Initial Setup

1. Create required Docker networks and volumes:
```bash
docker network create proxy
docker volume create acme
```

2. Configure environment variables for Traefik:
```bash
export CF_API_EMAIL="your-cloudflare-email@example.com"
export CF_DNS_API_TOKEN="your-cloudflare-dns-token"
export ACME_EMAIL="your-email@example.com"
```

3. Set up Mosquitto authentication:
```bash
cd docker/compose/mosquitto/config
cp acl.conf.example acl.conf
cp passwd.example passwd
# Edit passwd file with your MQTT users
```

### Starting Services

Start services in order:

```bash
# Start Traefik (reverse proxy)
cd docker/compose/traefik
docker compose up -d

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
cd docker/compose/traefik && docker compose down
cd ../mosquitto && docker compose down
cd ../website && docker compose down
```

## Configuration

### Domains

The infrastructure is configured for these domains:
- **Website**: `beta.ipnt.uk`
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

## Service Details

### Traefik
- Automatic HTTPS with Let's Encrypt
- Cloudflare DNS challenge for certificate generation
- Dashboard available at port 8080 (development only)
- Routes traffic based on Host headers

### Mosquitto MQTT Broker
- Eclipse Mosquitto 2.0
- Authentication required (no anonymous access)
- WebSocket support for web clients
- Access control via ACL configuration
- Persistent message storage

### Website
- Flask-based application
- Deployed from pre-built container images
- Production configuration

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

### Configuration Files

Key configuration files:
- `docker/compose/mosquitto/config/mosquitto.conf` - MQTT broker settings
- `docker/compose/mosquitto/config/acl.conf` - MQTT access control
- `docker/compose/mosquitto/config/passwd` - MQTT user authentication
- `docker/compose/traefik/config/static.yml` - Static Traefik routes

## Security

- All external traffic uses HTTPS with automatic certificate renewal
- MQTT broker requires authentication
- No anonymous access to MQTT topics
- Access control lists (ACL) define topic permissions

## Troubleshooting

### Certificate Issues
- Check Cloudflare API credentials
- Verify domain DNS is using Cloudflare
- Check Traefik logs: `docker compose logs traefik`

### MQTT Connection Issues
- Verify user credentials in `passwd` file
- Check ACL permissions in `acl.conf`
- Test connectivity: `mosquitto_pub -h mqtt.ipnt.uk -p 8883 -u username -P password -t test -m "hello"`

### Service Not Accessible
- Verify external network exists: `docker network ls | grep proxy`
- Check service labels in compose files
- Review Traefik dashboard for routing information
