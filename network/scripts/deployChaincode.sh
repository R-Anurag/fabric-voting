#!/usr/bin/env bash
set -e

echo "🔹 Deploying chaincode..."

cd /network

export FABRIC_CFG_PATH=/network/config

CC_NAME=voting
CC_VERSION=1.0
CC_PATH=/network/chaincode/voting

# ── Org1 Admin ────────────────────────────────────────────────────────────────
export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_MSPCONFIGPATH=/network/organizations/fabric-ca-client/org1/admin/msp
export CORE_PEER_ADDRESS=peer0.org1.example.com:7051

peer lifecycle chaincode package ${CC_NAME}.tar.gz \
  --path ${CC_PATH} \
  --lang golang \
  --label ${CC_NAME}_${CC_VERSION}

peer lifecycle chaincode install ${CC_NAME}.tar.gz

PKG_ID=$(peer lifecycle chaincode queryinstalled 2>&1 | grep "${CC_NAME}_${CC_VERSION}" | awk '{print $3}' | sed 's/,//')

# Get current committed sequence and increment, default to 1
COMMITTED=$(peer lifecycle chaincode querycommitted --channelID election-channel --name ${CC_NAME} 2>/dev/null | grep "Sequence:" | awk '{print $2}' | tr -d ',' || echo "0")
CC_SEQUENCE=$((COMMITTED + 1))

peer lifecycle chaincode approveformyorg \
  -o orderer.example.com:7050 \
  --channelID election-channel \
  --name ${CC_NAME} \
  --version ${CC_VERSION} \
  --package-id ${PKG_ID} \
  --sequence ${CC_SEQUENCE} \
  --signature-policy "OR('Org1MSP.member','Org2MSP.member')"

# ── Org2 Admin ────────────────────────────────────────────────────────────────
export CORE_PEER_LOCALMSPID=Org2MSP
export CORE_PEER_MSPCONFIGPATH=/network/organizations/fabric-ca-client/org2/admin/msp
export CORE_PEER_ADDRESS=peer0.org2.example.com:9051

peer lifecycle chaincode install ${CC_NAME}.tar.gz

peer lifecycle chaincode approveformyorg \
  -o orderer.example.com:7050 \
  --channelID election-channel \
  --name ${CC_NAME} \
  --version ${CC_VERSION} \
  --package-id ${PKG_ID} \
  --sequence ${CC_SEQUENCE} \
  --signature-policy "OR('Org1MSP.member','Org2MSP.member')"

# ── Commit ────────────────────────────────────────────────────────────────────
export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_MSPCONFIGPATH=/network/organizations/fabric-ca-client/org1/admin/msp
export CORE_PEER_ADDRESS=peer0.org1.example.com:7051

# Wait until both orgs are ready to commit
echo "⏳ Waiting for commit readiness..."
until peer lifecycle chaincode checkcommitreadiness \
  --channelID election-channel \
  --name ${CC_NAME} \
  --version ${CC_VERSION} \
  --sequence ${CC_SEQUENCE} \
  --signature-policy "OR('Org1MSP.member','Org2MSP.member')" \
  --output json 2>/dev/null | grep -q '"Org1MSP": true'; do
  sleep 3
done
echo "✅ Commit ready"

# Commit needs endorsements from BOTH orgs to satisfy LifecycleEndorsement (MAJORITY)
peer lifecycle chaincode commit \
  -o orderer.example.com:7050 \
  --channelID election-channel \
  --name ${CC_NAME} \
  --version ${CC_VERSION} \
  --sequence ${CC_SEQUENCE} \
  --signature-policy "OR('Org1MSP.member','Org2MSP.member')" \
  --peerAddresses peer0.org1.example.com:7051 \
  --peerAddresses peer0.org2.example.com:9051 \
  --waitForEvent

echo "✅ Chaincode deployed successfully"
