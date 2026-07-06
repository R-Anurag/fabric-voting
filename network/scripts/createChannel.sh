#!/usr/bin/env bash
set -e

echo "🔹 Creating channel..."

cd /network

export FABRIC_CFG_PATH=/network/config
export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_MSPCONFIGPATH=/network/organizations/fabric-ca-client/org1/admin/msp
export CORE_PEER_ADDRESS=peer0.org1.example.com:7051

# Wait for orderer to be reachable
echo "⏳ Waiting for orderer..."
until peer channel list -o orderer.example.com:7050 2>&1 | grep -v "Error\|failed" > /dev/null 2>&1 || \
      peer channel list -o orderer.example.com:7050 2>&1 | grep -q "Channels peers has joined"; do
  sleep 3
done
echo "✅ Orderer ready"

# Wait for peer
echo "⏳ Waiting for peer..."
until peer channel list > /dev/null 2>&1; do sleep 3; done
echo "✅ Peer ready"

# Create channel
peer channel create \
  -o orderer.example.com:7050 \
  -c election-channel \
  -f /network/channel-artifacts/channel.tx \
  --outputBlock /network/channel-artifacts/election-channel.block

# Join Org1 peer
peer channel join -b /network/channel-artifacts/election-channel.block

# Org2
export CORE_PEER_LOCALMSPID=Org2MSP
export CORE_PEER_MSPCONFIGPATH=/network/organizations/fabric-ca-client/org2/admin/msp
export CORE_PEER_ADDRESS=peer0.org2.example.com:9051

peer channel join -b /network/channel-artifacts/election-channel.block

echo "✅ Channel created and peers joined"
