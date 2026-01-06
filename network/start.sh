#!/usr/bin/env bash
set -e

echo "🔹 Starting Fabric network..."

# Always run from the network directory (script-safe)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Fabric config path (VERY IMPORTANT)
export FABRIC_CFG_PATH=$PWD/config

# Start CA containers first
echo "🔹 Starting Fabric CAs..."
docker compose -f docker/docker-compose-ca.yaml up -d

sleep 5

# Start orderer + peers
echo "🔹 Starting Fabric network containers..."
docker compose -f docker/docker-compose-network.yaml up -d

sleep 5

echo "🔹 Creating channel..."
bash scripts/createChannel.sh

sleep 3

echo "🔹 Deploying chaincode..."
bash scripts/deployChaincode.sh

echo "✅ Fabric network is READY"
