#!/bin/bash
  set -e
 
  echo ">>>>>>>>>>>>>>>>>>>>>>>Installing chaincode on buyer1"
  source ./config/changePeer/peer1-buyer1-setEnv.sh
  peer lifecycle chaincode install ./chaincode-external/basic_1.0.tar.gz

  echo ">>>>>>>>>>>>>>>>>>>>>>> Query package ID from buyer1 "
  PACKAGE_ID=$(peer lifecycle chaincode queryinstalled | grep "basic_1.0" | awk -F "[ ,]+" '{print $3}')

  ORGANIZATIONS=("buyer1" "logistics1" "supplier1" "warehouse1" "bank1")

  for org in "${ORGANIZATIONS[@]}"; do
    echo "Approving chaincode for organization: $org..."

    peer="peer1-${org}"

    source ./config/changePeer/${peer}-setEnv.sh
    MSP_ID="${org^}MSP"

    # 执行 approveformyorg
    peer lifecycle chaincode approveformyorg \
      -o orderer1-org0:7050 \
      --ordererTLSHostnameOverride orderer1-org0 \
      --tls \
      --cafile "$PROJECT_ROOT/organizations/ordererOrganizations/org0.example.com/orderers/orderer1-org0.org0.example.com/tls/ca.crt" \
      --channelID mychannel \
      --name basic \
      --version 1.0 \
      --package-id $PACKAGE_ID \
      --sequence 1 \
      --collections-config $PROJECT_ROOT/config/collections_config.json \
      --signature-policy "OR('Buyer1MSP.member','Supplier1MSP.member','Warehouse1MSP.member','Bank1MSP.member','Logistics1MSP.member')" \
      --peerAddresses $CORE_PEER_ADDRESS \
      --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE

    if [ $? -eq 0 ]; then
      echo "✅ Approved for $org"
    else
      echo "❌ Failed to approve for $org"
      exit 1
    fi
  done

