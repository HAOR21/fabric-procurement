#!/bin/bash
set -e

ROOT_DIR=${PWD}
FABRIC_CFG_PATH=""

# 解析命令行参数
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cfgPath)
      FABRIC_CFG_PATH="$2"
      shift 2  # 跳过参数名和它的值
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
done

# 检查 cfgPath 是否为空
if [ -z "$FABRIC_CFG_PATH" ]; then
  echo "Error: --fabric_cfg_path is required and cannot be empty."
  exit 1
fi


export FABRIC_CFG_PATH="$FABRIC_CFG_PATH"
# -------------------------------
# 工具函数
# -------------------------------
waitPort() {
  local HOST=$1
  local PORT=$2
  local TIMEOUT=${3:-30}
  local COUNT=0
  until nc -z $HOST $PORT; do
    sleep 1
    COUNT=$((COUNT+1))
    if [ $COUNT -ge $TIMEOUT ]; then
      echo "ERROR: $HOST:$PORT 启动超时"
      exit 1
    fi
  done
}

waitFile() {
  local FILE=$1
  local TIMEOUT=${2:-30}
  local COUNT=0
  until [ -f "$FILE" ]; do
    sleep 1
    COUNT=$((COUNT+1))
    if [ $COUNT -ge $TIMEOUT ]; then
      echo "ERROR: $FILE 超时未生成"
      exit 1
    fi
  done
}
initGenesis(){
  echo ">>> Generating genesis block and channel transaction..."
  ./config/gen-channel.sh
  echo ">>> Genesis block and channel.tx generated successfully."
}

runCAServer(){
echo ">>> Starting TLS and CA Servcer"
docker-compose -f ./docker/ca-tls/docker-compose-ca.yaml up -d
echo ">>> Starting successfully!"
}
# -------------------------------
# TLS-CA enroll
# -------------------------------
enrollTLSCA() {
  echo "等待 TLS-CA 启动..."
  waitPort localhost 7052
  waitFile ${ROOT_DIR}/organizations/fabric-ca/tls-ca/crypto/tls-cert.pem

  export FABRIC_CA_CLIENT_TLS_CERTFILES=${ROOT_DIR}/organizations/fabric-ca/tls-ca/crypto/tls-cert.pem
  export FABRIC_CA_CLIENT_HOME=${ROOT_DIR}/organizations/fabric-ca/tls-ca/admin

  echo "TLS-CA admin enroll..."
  fabric-ca-client enroll -d -u https://tls-ca-admin:tls-ca-adminpw@localhost:7052
}

# -------------------------------
# 组织 CA enroll & register
# -------------------------------
enrollCA() {
  local ADMIN_NAME=$1
  local ADMIN_PW=$2
  local CA_PORT=$3
  local ORG=$4

  export FABRIC_CA_CLIENT_TLS_CERTFILES=${ROOT_DIR}/organizations/fabric-ca/ca-${ORG}/crypto/ca-cert.pem
  export FABRIC_CA_CLIENT_HOME=${ROOT_DIR}/organizations/fabric-ca/ca-${ORG}/admin

  echo "Enroll CA admin for ${ORG}..."
  fabric-ca-client enroll -d -u https://${ADMIN_NAME}:${ADMIN_PW}@localhost:${CA_PORT}
}

registerIdentity() {
  local CA_PORT=$1
  local NAME=$2
  local SECRET=$3
  local TYPE=$4
  local ATTRS=$5

  echo "Register $TYPE $NAME..."
  if [ -z "$ATTRS" ]; then
    fabric-ca-client register -d --id.name $NAME --id.secret $SECRET --id.type $TYPE -u https://localhost:${CA_PORT}
  else
    fabric-ca-client register -d --id.name $NAME --id.secret $SECRET --id.type $TYPE --id.attrs "$ATTRS" -u https://localhost:${CA_PORT}
  fi
}

# -------------------------------
# 初始化 Orderer
# -------------------------------
initOrderer() {
  local ORDERER_NAME=$1
  local ORDERER_PW=$2
  local ORG_CA_PORT=$3
  local TLS_CA_PORT=$4
  local ORG_DOMAIN="org0.example.com"
  local ORDERER_DIR=${ROOT_DIR}/organizations/ordererOrganizations/${ORG_DOMAIN}/orderers/${ORDERER_NAME}.${ORG_DOMAIN}

  mkdir -p ${ORDERER_DIR}/msp ${ORDERER_DIR}/tls

  # MSP
  export FABRIC_CA_CLIENT_HOME=${ORDERER_DIR}
  export FABRIC_CA_CLIENT_TLS_CERTFILES=${ROOT_DIR}/organizations/fabric-ca/ca-org0/crypto/ca-cert.pem
  export FABRIC_CA_CLIENT_MSPDIR=msp
  fabric-ca-client enroll -d -u https://${ORDERER_NAME}:${ORDERER_PW}@localhost:${ORG_CA_PORT} --csr.hosts ${ORDERER_NAME}.${ORG_DOMAIN}

  # TLS
  export FABRIC_CA_CLIENT_MSPDIR=tls
  export FABRIC_CA_CLIENT_TLS_CERTFILES=${ROOT_DIR}/organizations/fabric-ca/tls-ca/crypto/tls-cert.pem
  fabric-ca-client enroll -d -u https://${ORDERER_NAME}:${ORDERER_PW}@localhost:${TLS_CA_PORT} --enrollment.profile tls --csr.hosts ${ORDERER_NAME}.${ORG_DOMAIN}

  # fix key name
  TLS_KEY=$(ls ${ORDERER_DIR}/tls/keystore/*_sk)
  mv $TLS_KEY ${ORDERER_DIR}/tls/keystore/key.pem
}

# -------------------------------
# 初始化 Peer
# -------------------------------
initPeer() {
  local PEER_NAME=$1
  local PEER_PW=$2
  local ORG_CA_PORT=$3
  local TLS_CA_PORT=$4
  local ORG=$5
  local ORG_DOMAIN="${ORG}.example.com"
  local PEER_DIR=${ROOT_DIR}/organizations/peerOrganizations/${ORG_DOMAIN}/peers/${PEER_NAME}.${ORG_DOMAIN}

  mkdir -p ${PEER_DIR}/msp ${PEER_DIR}/tls

  # MSP
  export FABRIC_CA_CLIENT_HOME=${PEER_DIR}
  export FABRIC_CA_CLIENT_TLS_CERTFILES=${ROOT_DIR}/organizations/fabric-ca/ca-${ORG}/crypto/ca-cert.pem
  export FABRIC_CA_CLIENT_MSPDIR=msp
  fabric-ca-client enroll -d -u https://${PEER_NAME}:${PEER_PW}@localhost:${ORG_CA_PORT} --csr.hosts ${PEER_NAME}.${ORG_DOMAIN}

  # TLS
  export FABRIC_CA_CLIENT_MSPDIR=tls
  export FABRIC_CA_CLIENT_TLS_CERTFILES=${ROOT_DIR}/organizations/fabric-ca/tls-ca/crypto/tls-cert.pem
  fabric-ca-client enroll -d -u https://${PEER_NAME}:${PEER_PW}@localhost:${TLS_CA_PORT} --enrollment.profile tls --csr.hosts ${PEER_NAME}.${ORG_DOMAIN}

  # fix key name
  TLS_KEY=$(ls ${PEER_DIR}/tls/keystore/*_sk)
  mv $TLS_KEY ${PEER_DIR}/tls/keystore/key.pem
}

# -------------------------------
# 初始化 User (Admin/User)
# -------------------------------
initUser() {
  local USER_NAME=$1
  local USER_PW=$2
  local ORG_CA_PORT=$3
  local ORG=$4
  local ORG_DOMAIN="${ORG}.example.com"
  local USER_DIR=${ROOT_DIR}/organizations/peerOrganizations/${ORG_DOMAIN}/users/${USER_NAME}@${ORG_DOMAIN}

  mkdir -p ${USER_DIR}/msp

  export FABRIC_CA_CLIENT_HOME=${USER_DIR}
  export FABRIC_CA_CLIENT_TLS_CERTFILES=${ROOT_DIR}/organizations/fabric-ca/ca-${ORG}/crypto/ca-cert.pem
  export FABRIC_CA_CLIENT_MSPDIR=msp
  fabric-ca-client enroll -d -u https://${USER_NAME}:${USER_PW}@localhost:${ORG_CA_PORT}
}

# -------------------------------
# 全流程示例
# -------------------------------
runTest() {
  export PATH=$PATH:${ROOT_DIR}/fabric-bin/bin
  echo "====1️⃣ Run CA server ===="
  runCAServer

  echo "==== 2️⃣  TLS-CA enroll ===="
  enrollTLSCA

  echo "==== 3️⃣ 各组织 RCA enroll + 注册 ===="
  # Orderer
  enrollCA "rca-org0-admin" "rca-org0-adminpw" 7053 "org0"
  registerIdentity 7053 "orderer1" "ordererpw" "orderer"
  registerIdentity 7053 "Admin-org0" "org0adminpw" "admin"

  # Buyer
  enrollCA "rca-buyer1-admin" "rca-buyer1-adminpw" 7054 "buyer1"
  registerIdentity 7054 "peer1" "buyer1PW" "peer"
  registerIdentity 7054 "Admin-buyer1" "buyer1AdminPW" "admin"
  registerIdentity 7054 "User1-buyer1" "buyer1UserPW" "user"

  # Supplier
  enrollCA "rca-supplier1-admin" "rca-supplier1-adminpw" 7055 "supplier1"
  registerIdentity 7055 "peer1" "supplier1PW" "peer"
  registerIdentity 7055 "Admin-supplier1" "supplier1AdminPW" "admin"
  registerIdentity 7055 "User1-supplier1" "supplier1UserPW" "user"

  # Logistics
  enrollCA "rca-logistics1-admin" "rca-logistics1-adminpw" 7056 "logistics1"
  registerIdentity 7056 "peer1" "logistics1PW" "peer"
  registerIdentity 7056 "Admin-logistics1" "logistics1AdminPW" "admin"
  registerIdentity 7056 "User1-logistics1" "logistics1UserPW" "user"

  # Warehouse
  enrollCA "rca-warehouse1-admin" "rca-warehouse1-adminpw" 7057 "warehouse1"
  registerIdentity 7057 "peer1" "warehouse1PW" "peer"
  registerIdentity 7057 "Admin-warehouse1" "warehouse1AdminPW" "admin"
  registerIdentity 7057 "User1-warehouse1" "warehouse1UserPW" "user"

  # Bank
  enrollCA "rca-bank1-admin" "rca-bank1-adminpw" 7058 "bank1"
  registerIdentity 7058 "peer1" "bank1PW" "peer"
  registerIdentity 7058 "Admin-bank1" "bank1AdminPW" "admin"
  registerIdentity 7058 "User1-bank1" "bank1UserPW" "user"

  echo "==== 4️⃣ 生成 MSP+TLS ===="
  initOrderer "orderer1" "ordererpw" 7053 7052
  initPeer "peer1" "buyer1PW" 7054 7052 "buyer1"
  initPeer "peer1" "supplier1PW" 7055 7052 "supplier1"
  initPeer "peer1" "logistics1PW" 7056 7052 "logistics1"
  initPeer "peer1" "warehouse1PW" 7057 7052 "warehouse1"
  initPeer "peer1" "bank1PW" 7058 7052 "bank1"

  echo "==== 5️⃣i生成用户 MSP ===="
  initUser "Admin-buyer1" "buyer1AdminPW" 7054 "buyer1"
  initUser "User1-buyer1" "buyer1UserPW" 7054 "buyer1"
  initUser "Admin-supplier1" "supplier1AdminPW" 7055 "supplier1"
  initUser "User1-supplier1" "supplier1UserPW" 7055 "supplier1"
  initUser "Admin-logistics1" "logistics1AdminPW" 7056 "logistics1"
  initUser "User1-logistics1" "logistics1UserPW" 7056 "logistics1"
  initUser "Admin-warehouse1" "warehouse1AdminPW" 7057 "warehouse1"
  initUser "User1-warehouse1" "warehouse1UserPW" 7057 "warehouse1"
  initUser "Admin-bank1" "bank1AdminPW" 7058 "bank1"
  initUser "User1-bank1" "bank1UserPW" 7058 "bank1"
  
  echo "====6️⃣init Genesis ===="
  initGenesis
  
  echo "7️⃣ init mychannel"
  ./fabric-procurement/config/gen-channel.sh

  echo "====start Peer docker===="
  docker compose -f ./dokcer/org01/docker-compose-org0.yaml up -d
  docker compose -f ./dokcer/buyer1/docker-compose-buyer1.yaml up -d
  docker compose -f ./dokcer/logistics1/docker-compose-logistics1.yaml up -d
  docker compose -f ./dokcer/supplier1/docker-compose-supplier1.yaml up -d
  docker compose -f ./dokcer/warehouse1/docker-compose-warehouse1.yaml up -d
  docker compose -f ./dokcer/bank1/docker-compose-bank1.yaml up -d
  
  echo "====create mychannel===="
  ./config/changePeer/orderer1-org0-setEnv.sh
  osnadmin channel join --channelID mychannel --config-block ./config/channel-artifacts/gen-mychannel.block -o org0.example.com:7050 --ca-file "./organizations/fabric-ca/ca-org0/crypto/ca-cert.pem" --client-cert "./organizations/fabric-ca/ca-org0/crypto/ca-cert.pem" --client-key "./organizations/fabric-ca/ca-org0/crypto/ca-cert.pem"
  ./config/changePeer/peer1-buyer1-setEnv.sh
  peer channel create -o org0.example.com:7050 -c mychannel -f ./config/channel-artifacts/channel.tx --outputBlock ./config/channel-artifacts/mychannel.block --cafile ./organizations/fabric-ca/ca-org0/crypto/ca-cert.pem
  echo "====create mychannel Done===="
  
  echo "====join mychannel===="
  #change peer to join mychannel
  peer channel join --blockfile ./config/channel-artifacts/mychannel.block --channelID mychannel --orderer orderer.example.com:7050 
  ./config/changePeer/peer1-logistics1-setEnv.sh
  peer channel join --blockfile ./config/channel-artifacts/mychannel.block --channelID mychannel --orderer orderer.example.com:7050
  ./config/changePeer/peer1-supplier1-setEnv.sh
  peer channel join --blockfile ./config/channel-artifacts/mychannel.block --channelID mychannel --orderer orderer.example.com:7050
  ./config/changePeer/peer1-warehouse1-setEnv.sh
  peer channel join --blockfile ./config/channel-artifacts/mychannel.block --channelID mychannel --orderer orderer.example.com:7050
  ./config/changePeer/peer1-bank1-setEnv.sh
  peer channel join --blockfile ./config/channel-artifacts/mychannel.block --channelID mychannel --orderer orderer.example.com:7050

  echo "==== 全流程 runTest 完成 ===="
}
