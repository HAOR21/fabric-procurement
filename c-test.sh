#!/bin/bash
  set -e

  PEERS=( "peer1-logistics1" "peer1-supplier1" "peer1-warehouse1" "peer1-bank1")

  # 循环所有组织，在各自的 peer1 上安装链码
  for peer in "${PEERS[@]}"; do
    echo ">>>>>>>>>>>>>>>>>>>>>>> Installing chaincode on $org"

    # 切换到对应 peer 的环境变量
    source ./config/changePeer/${peer}-setEnv.sh

    # 安装链码
    peer lifecycle chaincode install ./chaincode-external/basic_1.0.tgz

    if [ $? -eq 0 ]; then
      echo "✅ Chaincode installed on $peer"
    else
      echo "❌ Failed to install chaincode on $peer"
      exit 1
    fi
  done



  source ./config/changePeer/peer1-logistics1-setEnv.sh
  peer lifecycle chaincode commit \
    -o orderer1-org0:7050 \
    --ordererTLSHostnameOverride orderer1-org0 \
    --tls \
    --cafile "/etc/hyperledger/tlsca.crt" \
    --channelID mychannel \
    --name basic \
    --version 1.0 \
    --sequence 1 \
    --collections-config /etc/hyperledger/channel-artifacts/collections_config.json \
    --signature-policy "OR('Buyer1MSP.member','Supplier1MSP.member','Warehouse1MSP.member','Bank1MSP.member','Logistics1MSP.member')" \
    --peerAddresses peer1-buyer1:7051 \
    --tlsRootCertFiles "/etc/hyperledger/tls/ca.crt" \
    --peerAddresses peer1-bank1:8051 \
    --tlsRootCertFiles "$PROJECT_ROOT/organizations/peerOrganizations/bank1.example.com/peers/peer1-bank1.bank1.example.com/tls/ca.crt" \
    --peerAddresses peer1-logistics1:9051 \
    --tlsRootCertFiles "$PROJECT_ROOT/organizations/peerOrganizations/logistics1.example.com/peers/peer1-logistics1.logistics1.example.com/tls/ca.crt" \
    --peerAddresses peer1-supplier1:10051 \
    --tlsRootCertFiles "$PROJECT_ROOT/organizations/peerOrganizations/supplier1.example.com/peers/peer1-supplier1.supplier1.example.com/tls/ca.crt" \
    --peerAddresses peer1-warehouse1:11051 \
    --tlsRootCertFiles "$PROJECT_ROOT/organizations/peerOrganizations/warehouse1.example.com/peers/peer1-warehouse1.warehouse1.example.com/tls/ca.crt" \

