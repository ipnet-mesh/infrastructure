#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 3 ]; then
  echo "Usage: $0 <instance_dir> <image_version> <traefik_domain>"
  echo ""
  echo "Example:"
  echo "  $0 ../hub-prod v0.9.0 ipnt.uk"
  echo "  $0 ../hub-stg main beta.ipnt.uk"
  exit 1
fi

INSTANCE_DIR="$1"
IMAGE_VERSION="$2"
TRAEFIK_DOMAIN="$3"

REPO_BASE="https://raw.githubusercontent.com/ipnet-mesh/meshcore-hub/main"

COMPOSE_FILES=(
  "docker-compose.yml"
  "docker-compose.prod.yml"
  "docker-compose.traefik.yml"
  "docker-compose.dev.yml"
)

CONFIG_FILES=(
  "etc/prometheus/prometheus.yml"
  "etc/prometheus/alerts.yml"
  "etc/alertmanager/alertmanager.yml"
)

echo "Creating instance: ${INSTANCE_DIR}"
mkdir -p "${INSTANCE_DIR}"

for file in "${COMPOSE_FILES[@]}"; do
  echo "  Downloading ${file}..."
  curl -fsSL "${REPO_BASE}/${file}" -o "${INSTANCE_DIR}/${file}"
done

for file in "${CONFIG_FILES[@]}"; do
  echo "  Downloading ${file}..."
  mkdir -p "$(dirname "${INSTANCE_DIR}/${file}")"
  curl -fsSL "${REPO_BASE}/${file}" -o "${INSTANCE_DIR}/${file}"
done

if [ ! -f "${INSTANCE_DIR}/.env" ]; then
  echo "  Generating .env..."
  curl -fsSL "${REPO_BASE}/.env.example" -o "${INSTANCE_DIR}/.env"
  sed -i \
    -e "s|^COMPOSE_PROJECT_NAME=.*|COMPOSE_PROJECT_NAME=$(basename "${INSTANCE_DIR}")|" \
    -e "s|^IMAGE_VERSION=.*|IMAGE_VERSION=${IMAGE_VERSION}|" \
    "${INSTANCE_DIR}/.env"
  echo "" >> "${INSTANCE_DIR}/.env"
  echo "# Traefik domain for this instance" >> "${INSTANCE_DIR}/.env"
  echo "TRAEFIK_DOMAIN=${TRAEFIK_DOMAIN}" >> "${INSTANCE_DIR}/.env"
  echo "" >> "${INSTANCE_DIR}/.env"
  echo "# Shared infrastructure" >> "${INSTANCE_DIR}/.env"
  echo "MQTT_HOST=mqtt" >> "${INSTANCE_DIR}/.env"
  echo "CONTENT_HOME=../infrastructure/content" >> "${INSTANCE_DIR}/.env"
fi

echo ""
echo "Instance created at ${INSTANCE_DIR}"
echo "Edit ${INSTANCE_DIR}/.env to configure API keys, network settings, etc."
echo ""
echo "To start:"
echo "  cd ${INSTANCE_DIR} && docker compose -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.traefik.yml --profile core up -d"
