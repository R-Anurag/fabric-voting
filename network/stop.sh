#!/usr/bin/env bash
set -e

echo "🛑 Stopping Fabric network..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

docker compose \
  -f docker/docker-compose-ca.yaml \
  -f docker/docker-compose-network.yaml \
  down -v --remove-orphans

echo "✅ Fabric network stopped & cleaned"
