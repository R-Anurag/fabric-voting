#!/usr/bin/env bash
set -e

echo "🔹 Creating channel..."

# Always run from network root
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

export FABRIC_CFG_PATH=$PWD/config

# -------- Org1 Admin Context --------
export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/fabric-ca-client/org1/admin/msp
export CORE_PEER_ADDRESS=localhost:7051

# Create channel block
peer channel create \
  -o localhost:7050 \
  -c election-channel \
  -f config/channel.tx \
  --outputBlock channel-artifacts/election-channel.block

# Join Org1 peer
peer channel join -b channel-artifacts/election-channel.block

# -------- Org2 Admin Context --------
export CORE_PEER_LOCALMSPID=Org2MSP
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/fabric-ca-client/org2/admin/msp
export CORE_PEER_ADDRESS=localhost:9051

# Join Org2 peer
peer channel join -b channel-artifacts/election-channel.block

echo "✅ Channel created and peers joined"
