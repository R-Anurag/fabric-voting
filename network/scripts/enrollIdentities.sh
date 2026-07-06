#!/usr/bin/env bash
set -e

cd /network

export FABRIC_CA_CLIENT_HOME=/network/organizations/fabric-ca-client

# Remove shared client config to prevent it from interfering with per-CA enrollments
rm -f $FABRIC_CA_CLIENT_HOME/fabric-ca-client-config.yaml

ORDERER_TLS=/network/organizations/ca/orderer/tls-cert.pem
ORG1_TLS=/network/organizations/ca/org1/tls-cert.pem
ORG2_TLS=/network/organizations/ca/org2/tls-cert.pem

# ── Wait for CAs ──────────────────────────────────────────────────────────────
wait_for_ca() {
  local host=$1 tls=$2
  echo "⏳ Waiting for CA at $host..."
  until fabric-ca-client getcainfo -u https://$host:7054 --tls.certfiles $tls > /dev/null 2>&1; do sleep 2; done
  echo "✅ CA ready: $host"
}

wait_for_ca ca_orderer $ORDERER_TLS
wait_for_ca ca_org1    $ORG1_TLS
wait_for_ca ca_org2    $ORG2_TLS

# ── Helper: write NodeOU config.yaml ─────────────────────────────────────────
write_config() {
  local msp_dir=$1 cert_file=$2
  cat > "$msp_dir/config.yaml" <<EOF
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/$cert_file
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/$cert_file
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/$cert_file
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/$cert_file
    OrganizationalUnitIdentifier: orderer
EOF
}

# ── Enroll CA bootstrap admins ────────────────────────────────────────────────
fabric-ca-client enroll \
  -u https://admin:adminpw@ca_orderer:7054 --caname ca-orderer \
  --tls.certfiles $ORDERER_TLS \
  -M $FABRIC_CA_CLIENT_HOME/orderer/ca-admin/msp

fabric-ca-client enroll \
  -u https://admin:adminpw@ca_org1:7054 --caname ca-org1 \
  --tls.certfiles $ORG1_TLS \
  -M $FABRIC_CA_CLIENT_HOME/org1/ca-admin/msp

fabric-ca-client enroll \
  -u https://admin:adminpw@ca_org2:7054 --caname ca-org2 \
  --tls.certfiles $ORG2_TLS \
  -M $FABRIC_CA_CLIENT_HOME/org2/ca-admin/msp

# ── Orderer node ──────────────────────────────────────────────────────────────
fabric-ca-client register \
  -u https://admin:adminpw@ca_orderer:7054 --caname ca-orderer \
  --tls.certfiles $ORDERER_TLS \
  --mspdir $FABRIC_CA_CLIENT_HOME/orderer/ca-admin/msp \
  --id.name orderer1 --id.secret ordererpw --id.type orderer 2>/dev/null || true

fabric-ca-client enroll \
  -u https://orderer1:ordererpw@ca_orderer:7054 --caname ca-orderer \
  --tls.certfiles $ORDERER_TLS \
  -M $FABRIC_CA_CLIENT_HOME/orderer/node/msp

ORDERER_CACERT=$(ls $FABRIC_CA_CLIENT_HOME/orderer/node/msp/cacerts/*.pem | head -1 | xargs basename)
write_config $FABRIC_CA_CLIENT_HOME/orderer/node/msp "$ORDERER_CACERT"

# Orderer org-level MSP for configtxgen
mkdir -p $FABRIC_CA_CLIENT_HOME/orderer/msp/cacerts \
         $FABRIC_CA_CLIENT_HOME/orderer/msp/admincerts \
         $FABRIC_CA_CLIENT_HOME/orderer/msp/tlscacerts
cp $FABRIC_CA_CLIENT_HOME/orderer/node/msp/cacerts/*.pem \
   $FABRIC_CA_CLIENT_HOME/orderer/msp/cacerts/
cp $FABRIC_CA_CLIENT_HOME/orderer/ca-admin/msp/signcerts/*.pem \
   $FABRIC_CA_CLIENT_HOME/orderer/msp/admincerts/
cp $FABRIC_CA_CLIENT_HOME/orderer/node/msp/cacerts/*.pem \
   $FABRIC_CA_CLIENT_HOME/orderer/msp/tlscacerts/
write_config $FABRIC_CA_CLIENT_HOME/orderer/msp "$ORDERER_CACERT"

# ── Org1 peer0 ────────────────────────────────────────────────────────────────
fabric-ca-client register \
  -u https://admin:adminpw@ca_org1:7054 --caname ca-org1 \
  --tls.certfiles $ORG1_TLS \
  --mspdir $FABRIC_CA_CLIENT_HOME/org1/ca-admin/msp \
  --id.name peer0org1 --id.secret peer0pw --id.type peer 2>/dev/null || true

fabric-ca-client enroll \
  -u https://peer0org1:peer0pw@ca_org1:7054 --caname ca-org1 \
  --tls.certfiles $ORG1_TLS \
  -M $FABRIC_CA_CLIENT_HOME/org1/peer0/msp

ORG1_CACERT=$(ls $FABRIC_CA_CLIENT_HOME/org1/peer0/msp/cacerts/*.pem | head -1 | xargs basename)
write_config $FABRIC_CA_CLIENT_HOME/org1/peer0/msp "$ORG1_CACERT"

# ── Org1 admin ────────────────────────────────────────────────────────────────
fabric-ca-client register \
  -u https://admin:adminpw@ca_org1:7054 --caname ca-org1 \
  --tls.certfiles $ORG1_TLS \
  --mspdir $FABRIC_CA_CLIENT_HOME/org1/ca-admin/msp \
  --id.name org1admin --id.secret org1adminpw --id.type admin \
  --id.attrs "hf.Registrar.Roles=*,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert" 2>/dev/null || true

fabric-ca-client enroll \
  -u https://org1admin:org1adminpw@ca_org1:7054 --caname ca-org1 \
  --tls.certfiles $ORG1_TLS \
  -M $FABRIC_CA_CLIENT_HOME/org1/admin/msp

ORG1_ADMIN_CACERT=$(ls $FABRIC_CA_CLIENT_HOME/org1/admin/msp/cacerts/*.pem | head -1 | xargs basename)
write_config $FABRIC_CA_CLIENT_HOME/org1/admin/msp "$ORG1_ADMIN_CACERT"

mkdir -p $FABRIC_CA_CLIENT_HOME/org1/admin/msp/admincerts
cp $FABRIC_CA_CLIENT_HOME/org1/admin/msp/signcerts/*.pem \
   $FABRIC_CA_CLIENT_HOME/org1/admin/msp/admincerts/

mkdir -p $FABRIC_CA_CLIENT_HOME/org1/peer0/msp/admincerts
cp $FABRIC_CA_CLIENT_HOME/org1/admin/msp/signcerts/*.pem \
   $FABRIC_CA_CLIENT_HOME/org1/peer0/msp/admincerts/

# Org1 org-level MSP for configtxgen
mkdir -p $FABRIC_CA_CLIENT_HOME/org1/msp/cacerts \
         $FABRIC_CA_CLIENT_HOME/org1/msp/admincerts \
         $FABRIC_CA_CLIENT_HOME/org1/msp/tlscacerts
cp $FABRIC_CA_CLIENT_HOME/org1/peer0/msp/cacerts/*.pem \
   $FABRIC_CA_CLIENT_HOME/org1/msp/cacerts/
cp $FABRIC_CA_CLIENT_HOME/org1/admin/msp/signcerts/*.pem \
   $FABRIC_CA_CLIENT_HOME/org1/msp/admincerts/
cp $FABRIC_CA_CLIENT_HOME/org1/peer0/msp/cacerts/*.pem \
   $FABRIC_CA_CLIENT_HOME/org1/msp/tlscacerts/
write_config $FABRIC_CA_CLIENT_HOME/org1/msp "$ORG1_CACERT"

# ── Org2 peer0 ────────────────────────────────────────────────────────────────
fabric-ca-client register \
  -u https://admin:adminpw@ca_org2:7054 --caname ca-org2 \
  --tls.certfiles $ORG2_TLS \
  --mspdir $FABRIC_CA_CLIENT_HOME/org2/ca-admin/msp \
  --id.name peer0org2 --id.secret peer0pw --id.type peer 2>/dev/null || true

fabric-ca-client enroll \
  -u https://peer0org2:peer0pw@ca_org2:7054 --caname ca-org2 \
  --tls.certfiles $ORG2_TLS \
  -M $FABRIC_CA_CLIENT_HOME/org2/peer0/msp

ORG2_CACERT=$(ls $FABRIC_CA_CLIENT_HOME/org2/peer0/msp/cacerts/*.pem | head -1 | xargs basename)
write_config $FABRIC_CA_CLIENT_HOME/org2/peer0/msp "$ORG2_CACERT"

# ── Org2 admin ────────────────────────────────────────────────────────────────
fabric-ca-client register \
  -u https://admin:adminpw@ca_org2:7054 --caname ca-org2 \
  --tls.certfiles $ORG2_TLS \
  --mspdir $FABRIC_CA_CLIENT_HOME/org2/ca-admin/msp \
  --id.name org2admin --id.secret org2adminpw --id.type admin \
  --id.attrs "hf.Registrar.Roles=*,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert" 2>/dev/null || true

fabric-ca-client enroll \
  -u https://org2admin:org2adminpw@ca_org2:7054 --caname ca-org2 \
  --tls.certfiles $ORG2_TLS \
  -M $FABRIC_CA_CLIENT_HOME/org2/admin/msp

ORG2_ADMIN_CACERT=$(ls $FABRIC_CA_CLIENT_HOME/org2/admin/msp/cacerts/*.pem | head -1 | xargs basename)
write_config $FABRIC_CA_CLIENT_HOME/org2/admin/msp "$ORG2_ADMIN_CACERT"

mkdir -p $FABRIC_CA_CLIENT_HOME/org2/admin/msp/admincerts
cp $FABRIC_CA_CLIENT_HOME/org2/admin/msp/signcerts/*.pem \
   $FABRIC_CA_CLIENT_HOME/org2/admin/msp/admincerts/

mkdir -p $FABRIC_CA_CLIENT_HOME/org2/peer0/msp/admincerts
cp $FABRIC_CA_CLIENT_HOME/org2/admin/msp/signcerts/*.pem \
   $FABRIC_CA_CLIENT_HOME/org2/peer0/msp/admincerts/

# Org2 org-level MSP for configtxgen
mkdir -p $FABRIC_CA_CLIENT_HOME/org2/msp/cacerts \
         $FABRIC_CA_CLIENT_HOME/org2/msp/admincerts \
         $FABRIC_CA_CLIENT_HOME/org2/msp/tlscacerts
cp $FABRIC_CA_CLIENT_HOME/org2/peer0/msp/cacerts/*.pem \
   $FABRIC_CA_CLIENT_HOME/org2/msp/cacerts/
cp $FABRIC_CA_CLIENT_HOME/org2/admin/msp/signcerts/*.pem \
   $FABRIC_CA_CLIENT_HOME/org2/msp/admincerts/
cp $FABRIC_CA_CLIENT_HOME/org2/peer0/msp/cacerts/*.pem \
   $FABRIC_CA_CLIENT_HOME/org2/msp/tlscacerts/
write_config $FABRIC_CA_CLIENT_HOME/org2/msp "$ORG2_CACERT"

echo "✅ All identities enrolled"
