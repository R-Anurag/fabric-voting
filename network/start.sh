#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

export FABRIC_CFG_PATH=$PWD/config

# ── 1. Ensure Docker network exists ──────────────────────────────────────────
docker network inspect evoting_net > /dev/null 2>&1 || docker network create evoting_net
echo "✅ Network evoting_net ready"

# ── 2. Wipe stale CA-generated artifacts (preserve config yamls) ─────────────
echo "🔹 Cleaning stale CA artifacts..."
for org in orderer org1 org2; do
  rm -f  organizations/ca/$org/ca-cert.pem \
         organizations/ca/$org/tls-cert.pem \
         organizations/ca/$org/fabric-ca-server.db \
         organizations/ca/$org/IssuerPublicKey \
         organizations/ca/$org/IssuerRevocationPublicKey \
         organizations/ca/$org/ca-chain.pem
  rm -rf organizations/ca/$org/msp
done

# ── 3. Wipe stale MSP data ────────────────────────────────────────────────────
echo "🔹 Cleaning stale MSP data..."
rm -rf organizations/fabric-ca-client/orderer \
       organizations/fabric-ca-client/org1 \
       organizations/fabric-ca-client/org2
mkdir -p organizations/fabric-ca-client/orderer \
         organizations/fabric-ca-client/org1 \
         organizations/fabric-ca-client/org2

# ── 4. Start CA containers ────────────────────────────────────────────────────
echo "🔹 Starting CA containers..."
docker compose -f docker/docker-compose-ca.yaml up -d

# ── 5. Wait for CAs to write their TLS certs (poll file size, not sleep) ──────
echo "⏳ Waiting for CA TLS certs to be generated..."
for org in orderer org1 org2; do
  until [ -s "organizations/ca/$org/tls-cert.pem" ]; do sleep 1; done
  echo "✅ CA $org cert ready"
done

# ── 6. Copy TLS certs properly via docker cp ─────────────────────────────────
echo "🔹 Copying TLS certs from CA containers..."
docker cp ca_orderer:/etc/hyperledger/fabric-ca-server/tls-cert.pem organizations/ca/orderer/tls-cert.pem
docker cp ca_org1:/etc/hyperledger/fabric-ca-server/tls-cert.pem    organizations/ca/org1/tls-cert.pem
docker cp ca_org2:/etc/hyperledger/fabric-ca-server/tls-cert.pem    organizations/ca/org2/tls-cert.pem

# ── 7. Enroll all identities ──────────────────────────────────────────────────
echo "🔹 Enrolling identities..."
docker rm -f fabric-enroll 2>/dev/null || true
docker run --rm \
  --name fabric-enroll \
  --network evoting_net \
  -v "$PWD:/network" \
  hyperledger/fabric-ca:1.5.15 \
  bash /network/scripts/enrollIdentities.sh

# ── 8. Regenerate genesis.block and channel.tx with fresh MSP certs ───────────
echo "🔹 Regenerating genesis block and channel.tx..."
rm -f channel-artifacts/genesis.block channel-artifacts/channel.tx channel-artifacts/election-channel.block
docker run --rm \
  --name fabric-configtxgen \
  -v "$PWD:/network" \
  -e FABRIC_CFG_PATH=/network/config \
  hyperledger/fabric-tools:2.5.4 \
  sh -c "
    configtxgen -profile ElectionGenesis  -channelID system-channel -outputBlock /network/channel-artifacts/genesis.block &&
    configtxgen -profile ElectionChannel  -channelID election-channel -outputCreateChannelTx /network/channel-artifacts/channel.tx
  "

# ── 9. Start orderer and peers ────────────────────────────────────────────────
echo "🔹 Starting Fabric network..."
docker compose -f docker/docker-compose-network.yaml up -d

# ── 10. Run channel creation and chaincode deployment inside fabric-cli ────────
echo "🔹 Waiting for network containers to be ready..."
sleep 8

echo "🔹 Creating channel..."
docker run --rm \
  --name fabric-channel \
  --network evoting_net \
  -v "$PWD:/network" \
  -e FABRIC_CFG_PATH=/network/config \
  hyperledger/fabric-tools:2.5.4 \
  bash /network/scripts/createChannel.sh

echo "🔹 Deploying chaincode..."
docker run --rm \
  --name fabric-deploy \
  --network evoting_net \
  -v "$PWD:/network" \
  -e FABRIC_CFG_PATH=/network/config \
  hyperledger/fabric-tools:2.5.4 \
  bash /network/scripts/deployChaincode.sh

echo "✅ Fabric network is READY"
