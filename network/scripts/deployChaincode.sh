#!/bin/bash
set -e

CC_NAME=voting
CC_VERSION=1.1
CC_SEQUENCE=7
CC_PATH=chaincode/voting

peer lifecycle chaincode package ${CC_NAME}.tar.gz \
  --path ${CC_PATH} \
  --lang golang \
  --label ${CC_NAME}_${CC_VERSION}

# Org1
export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/fabric-ca-client/org1/admin/msp
export CORE_PEER_ADDRESS=localhost:7051
peer lifecycle chaincode install ${CC_NAME}.tar.gz

# Org2
export CORE_PEER_LOCALMSPID=Org2MSP
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/fabric-ca-client/org2/admin/msp
export CORE_PEER_ADDRESS=localhost:9051
peer lifecycle chaincode install ${CC_NAME}.tar.gz

# Approve
peer lifecycle chaincode approveformyorg \
  --channelID election-channel \
  --name ${CC_NAME} \
  --version ${CC_VERSION} \
  --sequence ${CC_SEQUENCE} \
  --orderer localhost:7050

# Commit
peer lifecycle chaincode commit \
  --channelID election-channel \
  --name ${CC_NAME} \
  --version ${CC_VERSION} \
  --sequence ${CC_SEQUENCE} \
  --orderer localhost:7050 \
  --peerAddresses localhost:7051 \
  --peerAddresses localhost:9051
