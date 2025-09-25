#!/bin/bash
  set -e
 
  echo "====9️⃣ Committing chaincode definition ===="

  # 任选一个组织来执行 commit
  source ./config/changePeer/peer1-logistics1-setEnv.sh
  env
  peer lifecycle chaincode commit \
    -o orderer1-org0:7050 \
    --ordererTLSHostnameOverride orderer1-org0 \
    --tls \
    --cafile "$PROJECT_ROOT/organizations/ordererOrganizations/org0.example.com/orderers/orderer1-org0.org0.example.com/tls/ca.crt" \
    --channelID mychannel \
    --name basic \
    --version 1.0 \
    --sequence 1 \
    --collections-config $PROJECT_ROOT/config/collections_config.json \
    --signature-policy "OR('Buyer1MSP.member','Logistics1MSP.member','Supplier1MSP.member','Warehouse1MSP.member','Bank1MSP.member')" \
    --peerAddresses peer1-buyer1:7051 \
    --peerAddresses peer1-logistics1:7051 \
    --peerAddresses peer1-supplier1:7051 \
    --peerAddresses peer1-warehouse1:7051 \
    --peerAddresses peer1-bank1:7051 \
    --tlsRootCertFiles "$PROJECT_ROOT/organizations/peerOrganizations/buyer1.example.com/peers/peer1-buyer1.buyer1.example.com/tls/ca.crt" \
    --tlsRootCertFiles "$PROJECT_ROOT/organizations/peerOrganizations/logistics1.example.com/peers/peer1-logistics1.logistics1.example.com/tls/ca.crt" \
    --tlsRootCertFiles "$PROJECT_ROOT/organizations/peerOrganizations/supplier1.example.com/peers/peer1-supplier1.supplier1.example.com/tls/ca.crt" \
    --tlsRootCertFiles "$PROJECT_ROOT/organizations/peerOrganizations/warehouse1.example.com/peers/peer1-warehouse1.warehouse1.example.com/tls/ca.crt" \
    --tlsRootCertFiles "$PROJECT_ROOT/organizations/peerOrganizations/bank1.example.com/peers/peer1-bank1.bank1.example.com/tls/ca.crt"


