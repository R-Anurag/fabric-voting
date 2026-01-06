#!/bin/bash
set -e

echo "Starting Fabric network..."
docker compose up -d

sleep 5

echo "Creating channel..."
./scripts/createChannel.sh

echo "Deploying chaincode..."
./scripts/deployChaincode.sh

echo "Fabric network is ready."
