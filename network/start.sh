#!/usr/bin/env bash
set -e

echo "🔹 Starting Fabric network..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

export FABRIC_CFG_PATH=$PWD/config

# Start everything together
docker compose \
  -f docker/docker-compose-ca.yaml \
  -f docker/docker-compose-network.yaml \
  up -d

sleep 6

echo "🔹 Creating channel..."
bash scripts/createChannel.sh

sleep 3

echo "🔹 Deploying chaincode..."
bash scripts/deployChaincode.sh

echo "✅ Fabric network is READY"
