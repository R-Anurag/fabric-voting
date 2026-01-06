#!/bin/bash
set -e

export FABRIC_CFG_PATH=$PWD/config

peer channel create \
  -o localhost:7050 \
  -c election-channel \
  -f channel-artifacts/channel.tx

peer channel join -b election-channel.block
