#!/usr/bin/env bash
set -e

echo "🛑 Stopping Fabric network..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

docker compose \
  -f docker/docker-compose-ca.yaml \
  -f docker/docker-compose-network.yaml \
  down --remove-orphans

docker rm -f fabric-enroll fabric-channel fabric-deploy fabric-configtxgen 2>/dev/null || true

echo "✅ Fabric network stopped"
