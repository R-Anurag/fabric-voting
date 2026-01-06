#!/usr/bin/env bash
set -e

echo "🔹 Deploying chaincode..."

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

export FABRIC_CFG_PATH=$PWD/config

CC_NAME=voting
CC_VERSION=1.1
CC_SEQUENCE=1
CC_PATH=chaincode/voting

# -------- Org1 Admin --------
export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/fabric-ca-client/org1/admin/msp
export CORE_PEER_ADDRESS=localhost:7051

peer lifecycle chaincode package ${CC_NAME}.tar.gz \
  --path ${CC_PATH} \
  --lang golang \
  --label ${CC_NAME}_${CC_VERSION}

peer lifecycle chaincode install ${CC_NAME}.tar.gz

PKG_ID=$(peer lifecycle chaincode queryinstalled | grep ${CC_NAME}_${CC_VERSION} | awk '{print $3}' | sed 's/,//')

peer lifecycle chaincode approveformyorg \
  -o localhost:7050 \
  --channelID election-channel \
  --name ${CC_NAME} \
  --version ${CC_VERSION} \
  --package-id ${PKG_ID} \
  --sequence ${CC_SEQUENCE}

# -------- Org2 Admin --------
export CORE_PEER_LOCALMSPID=Org2MSP
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/fabric-ca-client/org2/admin/msp
export CORE_PEER_ADDRESS=localhost:9051

peer lifecycle chaincode install ${CC_NAME}.tar.gz

peer lifecycle chaincode approveformyorg \
  -o localhost:7050 \
  --channelID election-channel \
  --name ${CC_NAME} \
  --version ${CC_VERSION} \
  --package-id ${PKG_ID} \
  --sequence ${CC_SEQUENCE}

# -------- Commit (Org1 context) --------
export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/fabric-ca-client/org1/admin/msp
export CORE_PEER_ADDRESS=localhost:7051

peer lifecycle chaincode commit \
  -o localhost:7050 \
  --channelID election-channel \
  --name ${CC_NAME} \
  --version ${CC_VERSION} \
  --sequence ${CC_SEQUENCE} \
  --peerAddresses localhost:7051 \
  --peerAddresses localhost:9051

echo "✅ Chaincode deployed successfully"
