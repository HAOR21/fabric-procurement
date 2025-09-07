#!/bin/bash
set -e

ROOT_DIR=${PWD}

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

# -------------------------------
# TLS-CA enroll
# -------------------------------
enrollTLSCA() {
  echo "等待 TLS-CA 启动..."
  waitPort localhost 7052
  waitFile ${ROOT_DIR}/organizations/fabric-ca/tls/crypto/tls-cert.pem

  export FABRIC_CA_CLIENT_TLS_CERTFILES=${ROOT_DIR}/organizations/fabric-ca/tls/crypto/tls-cert.pem
  export FABRIC_CA_CLIENT_HOME=${ROOT_DIR}/organizations/fabric-ca/tls/admin

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

  export FABRIC_CA_CLIENT_TLS_CERTFILES=${ROOT_DIR}/organizations/fabric-ca/${ORG}/crypto/ca-cert.pem
  export FABRIC_CA_CLIENT_HOME=${ROOT_DIR}/organizations/fabric-ca/${ORG}/admin

  echo "Enroll CA admin for ${ORG}..."
  fabric-ca-client enroll -d -u https://${ADMIN_NAME}:${ADMIN_PW}@localhost:${CA_PORT}
}

registerPeer() {
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
# Peer enroll + TLS enroll
# -------------------------------
initPeer() {
  local PEER_NAME=$1
  local PEER_PW=$2
  local ORG_CA_PORT=$3
  local TLS_CA_PORT=$4
  local ORG=$5

  local ORG_DIR=${ROOT_DIR}/organizations/fabric-ca/${ORG}

  # 1️⃣ MSP enroll
  export FABRIC_CA_CLIENT_HOME=${ORG_DIR}/peers/${PEER_NAME}/msp
  export FABRIC_CA_CLIENT_TLS_CERTFILES=${ORG_DIR}/crypto/ca-cert.pem
  export FABRIC_CA_CLIENT_MSPDIR=msp
  echo "Enroll MSP for $PEER_NAME..."
  fabric-ca-client enroll -d -u https://${PEER_NAME}:${PEER_PW}@localhost:${ORG_CA_PORT}

  # 2️⃣ TLS enroll
  export FABRIC_CA_CLIENT_MSPDIR=tls-msp
  export FABRIC_CA_CLIENT_TLS_CERTFILES=${ROOT_DIR}/organizations/fabric-ca/tls/crypto/tls-cert.pem
  echo "Enroll TLS for $PEER_NAME..."
  fabric-ca-client enroll -d -u https://${PEER_NAME}:${PEER_PW}@localhost:${TLS_CA_PORT} --enrollment.profile tls --csr.hosts ${PEER_NAME}

  # 3️⃣ 修改 keystore 文件名为 key.pem
  TLS_KEY=$(ls ${ORG_DIR}/peers/${PEER_NAME}/tls-msp/keystore/*_sk)
  mv $TLS_KEY ${ORG_DIR}/peers/${PEER_NAME}/tls-msp/keystore/key.pem
}

#todo:后期增加自定义文件路径可选项
initGenesis(){
  echo ">>> Generating genesis block and channel transaction..."
  ./config/gen-channel.sh
  echo ">>> Genesis block and channel.tx generated successfully."
}

# -------------------------------
# 全流程函数（示例流程）
# -------------------------------
runTest() {
  echo "==== 1️⃣ TLS-CA enroll ===="
  enrollTLSCA

  echo "==== 2️⃣ 组织 RCA enroll + 注册节点 ===="
  # Orderer
  enrollCA "rca-org0-admin" "rca-org0-adminpw" 7053 "org0"
  registerPeer 7053 "orderer1-org0" "ordererpw" "orderer"
  registerPeer 7053 "admin-org0" "org0adminpw" "admin" "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"

  # Buyer
  enrollCA "rca-buyer1-admin" "rca-buyer1-adminpw" 7054 "buyer1"
  registerPeer 7054 "peer1-buyer1" "buyer1PW" "peer"
  registerPeer 7054 "admin-buyer1" "buyer1AdminPW" "admin"
  registerPeer 7054 "user-buyer1" "buyer1UserPW" "user"

  # Supplier
  enrollCA "rca-supplier1-admin" "rca-supplier1-adminpw" 7055 "supplier1"
  registerPeer 7055 "peer1-supplier1" "supplier1PW" "peer"
  registerPeer 7055 "admin-supplier1" "supplier1AdminPW" "admin"
  registerPeer 7055 "user-supplier1" "supplier1UserPW" "user"

  # Logistics
  enrollCA "rca-logistics1-admin" "rca-logistics1-adminpw" 7056 "logistics1"
  registerPeer 7056 "peer1-logistics1" "logistics1PW" "peer"
  registerPeer 7056 "admin-logistics1" "logistics1AdminPW" "admin"
  registerPeer 7056 "user-logistics1" "logistics1UserPW" "user"

  # Warehouse
  enrollCA "rca-warehouse1-admin" "rca-warehouse1-adminpw" 7057 "warehouse1"
  registerPeer 7057 "peer1-warehouse1" "warehouse1PW" "peer"
  registerPeer 7057 "admin-warehouse1" "warehouse1AdminPW" "admin"
  registerPeer 7057 "user-warehouse1" "warehouse1UserPW" "user"

  # Bank
  enrollCA "rca-bank1-admin" "rca-bank1-adminpw" 7058 "bank1"
  registerPeer 7058 "peer1-bank1" "bank1PW" "peer"
  registerPeer 7058 "admin-bank1" "bank1AdminPW" "admin"
  registerPeer 7058 "user-bank1" "bank1UserPW" "user"

  echo "==== 3️⃣ Peer MSP + TLS enroll ===="
  initPeer "peer1-buyer1" "buyer1PW" 7054 7052 "buyer1"
  initPeer "peer1-supplier1" "supplier1PW" 7055 7052 "supplier1"
  initPeer "peer1-logistics1" "logistics1PW" 7056 7052 "logistics1"
  initPeer "peer1-warehouse1" "warehouse1PW" 7057 7052 "warehouse1"
  initPeer "peer1-bank1" "bank1PW" 7058 7052 "bank1"



  echo "==== 全流程 runTest 完成 ===="
}

