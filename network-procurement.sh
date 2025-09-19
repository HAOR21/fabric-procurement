#!/bin/bash
set -e

export FABRIC_LOGGING_SPEC=DEBUG
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
docker compose -f ./docker/ca-tls/docker-compose-ca.yaml up -d
echo ">>> Starting successfully!"
}
# -------------------------------
# TLS-CA enroll
# -------------------------------
enrollTLSCA() {
  echo "等待 TLS-CA 启动..."
  export FABRIC_CA_CLIENT_TLS_CERTFILES=${ROOT_DIR}/organizations/fabric-ca/tls-ca/crypto/tls-cert.pem
  export FABRIC_CA_CLIENT_HOME=${ROOT_DIR}/organizations/fabric-ca/tls-ca/admin

  waitPort localhost 7052
  waitFile ${FABRIC_CA_CLIENT_TLS_CERTFILES}

  echo ">>>>>TLS-CA admin enroll..."
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

  export FABRIC_CA_CLIENT_TLS_CERTFILES=${ROOT_DIR}/organizations/fabric-ca/${ORG}/crypto/tls-cert.pem
  export FABRIC_CA_CLIENT_HOME=${ROOT_DIR}/organizations/fabric-ca/${ORG}/admin

  echo ">>>>>Enroll CA admin for ${ORG}..."
  fabric-ca-client enroll -d -u https://${ADMIN_NAME}:${ADMIN_PW}@localhost:${CA_PORT} \
    --mspdir $FABRIC_CA_CLIENT_HOME/msp \
    --tls.certfiles $FABRIC_CA_CLIENT_TLS_CERTFILES
}
registerIdentity() {
  local CA_PORT=$1
  local NAME=$2
  local SECRET=$3
  local TYPE=$4 
  local ATTRS=$5

  echo ">>>>>Register $TYPE $NAME..."
  if [ -z "$ATTRS" ]; then
    fabric-ca-client register -d --id.name $NAME --id.secret $SECRET --id.type $TYPE -u https://localhost:${CA_PORT}
  else
    fabric-ca-client register -d --id.name $NAME --id.secret $SECRET --id.type $TYPE --id.attrs "$ATTRS" -u https://localhost:${CA_PORT}
  fi
}

# MSP 注册函数
registerMSPIdentity() {
  local CA_PORT=$1
  local NAME=$2
  local SECRET=$3
  local TYPE=$4
  local ORG=$5
  local ATTRS=$6

  export FABRIC_CA_CLIENT_HOME=${ROOT_DIR}/organizations/fabric-ca/${ORG}/admin
  export FABRIC_CA_CLIENT_TLS_CERTFILES=${ROOT_DIR}/organizations/fabric-ca/${ORG}/crypto/tls-cert.pem

  echo ">>>>>Register MSP identity $NAME for $ORG..."
  
  if [ -z "$ATTRS" ]; then
    fabric-ca-client register -d \
      --id.name $NAME \
      --id.secret $SECRET \
      --id.type $TYPE \
      -u https://localhost:${CA_PORT} \
      --mspdir $FABRIC_CA_CLIENT_HOME/msp \
      --tls.certfiles $FABRIC_CA_CLIENT_TLS_CERTFILES
  else
    fabric-ca-client register -d \
      --id.name $NAME \
      --id.secret $SECRET \
      --id.type $TYPE \
      --id.attrs "$ATTRS" \
      -u https://localhost:${CA_PORT} \
      --mspdir $FABRIC_CA_CLIENT_HOME/msp \
      --tls.certfiles $FABRIC_CA_CLIENT_TLS_CERTFILES
  fi
}

# TLS 注册函数
registerTLSIdentity() {
  local CA_PORT=$1
  local NAME=$2
  local SECRET=$3
  local TYPE=$4
  local ATTRS=$5

  export FABRIC_CA_CLIENT_HOME=${ROOT_DIR}/organizations/fabric-ca/tls-ca/admin
  export FABRIC_CA_CLIENT_TLS_CERTFILES=${ROOT_DIR}/organizations/fabric-ca/tls-ca/crypto/tls-cert.pem

  echo ">>>>>Register TLS identity $NAME..."
  
  if [ -z "$ATTRS" ]; then
    fabric-ca-client register -d \
      --id.name $NAME \
      --id.secret $SECRET \
      --id.type $TYPE \
      -u https://localhost:${CA_PORT} \
      --mspdir $FABRIC_CA_CLIENT_HOME/msp \
      --tls.certfiles $FABRIC_CA_CLIENT_TLS_CERTFILES
  else
    fabric-ca-client register -d \
      --id.name $NAME \
      --id.secret $SECRET \
      --id.type $TYPE \
      --id.attrs "$ATTRS" \
      -u https://localhost:${CA_PORT} \
      --mspdir $FABRIC_CA_CLIENT_HOME/msp \
      --tls.certfiles $FABRIC_CA_CLIENT_TLS_CERTFILES
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
  export FABRIC_CA_CLIENT_TLS_CERTFILES=${ROOT_DIR}/organizations/fabric-ca/org0/crypto/ca-cert.pem
  export FABRIC_CA_CLIENT_MSPDIR=msp
  fabric-ca-client enroll -d -u https://${ORDERER_NAME}:${ORDERER_PW}@localhost:${ORG_CA_PORT} --csr.hosts ${ORDERER_NAME}.${ORG_DOMAIN} --csr.names OU=orderer

  # TLS
  export FABRIC_CA_CLIENT_MSPDIR=tls
  export FABRIC_CA_CLIENT_TLS_CERTFILES=${ROOT_DIR}/organizations/fabric-ca/tls-ca/crypto/tls-cert.pem

  fabric-ca-client enroll -d -u https://${ORDERER_NAME}:${ORDERER_PW}@localhost:${TLS_CA_PORT} --enrollment.profile tls --csr.hosts ${ORDERER_NAME}.${ORG_DOMAIN},localhost

  # >>>>>>>>>> 添加生成 config.yaml <<<<<<<<<<
  cat <<EOF > "${ORDERER_DIR}/msp/config.yaml"
  NodeOUs:
    Enable: true
    ClientOUIdentifier:
      OrganizationalUnitIdentifier: client
    PeerOUIdentifier:
      OrganizationalUnitIdentifier: peer
    AdminOUIdentifier:
      OrganizationalUnitIdentifier: admin
    OrdererOUIdentifier: 
      OrganizationalUnitIdentifier: orderer
EOF
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
  export FABRIC_CA_CLIENT_TLS_CERTFILES=${ROOT_DIR}/organizations/fabric-ca/${ORG}/crypto/ca-cert.pem
  export FABRIC_CA_CLIENT_MSPDIR=msp
  fabric-ca-client enroll -d -u https://${PEER_NAME}:${PEER_PW}@localhost:${ORG_CA_PORT} --csr.hosts ${PEER_NAME}.${ORG_DOMAIN} --csr.names OU=peer

  # TLS
  export FABRIC_CA_CLIENT_MSPDIR=tls
  export FABRIC_CA_CLIENT_TLS_CERTFILES=${ROOT_DIR}/organizations/fabric-ca/tls-ca/crypto/tls-cert.pem
  fabric-ca-client enroll -d -u https://${PEER_NAME}:${PEER_PW}@localhost:${TLS_CA_PORT} --enrollment.profile tls --csr.hosts ${PEER_NAME}.${ORG_DOMAIN}

  # >>>>>>>>>> 添加生成 config.yaml <<<<<<<<<<
  cat <<EOF > "${PEER_DIR}/msp/config.yaml"
  NodeOUs:
    Enable: true
    ClientOUIdentifier:
      OrganizationalUnitIdentifier: client
    PeerOUIdentifier: # Peer MSP 需要识别自己是 Peer
      OrganizationalUnitIdentifier: peer
    AdminOUIdentifier:
      OrganizationalUnitIdentifier: admin
    OrdererOUIdentifier: # 可选，如果需要验证 Orderer 证书
      OrganizationalUnitIdentifier: orderer
EOF

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
  if [[ $ORG == org* ]]; then
    local USER_DIR=${ROOT_DIR}/organizations/ordererOrganizations/${ORG_DOMAIN}/users/${USER_NAME}@${ORG_DOMAIN}
  else
    local USER_DIR=${ROOT_DIR}/organizations/peerOrganizations/${ORG_DOMAIN}/users/${USER_NAME}@${ORG_DOMAIN}
  fi

  mkdir -p ${USER_DIR}/msp
  local first_four_chars="${USER_NAME:0:4}"  # 提取前4个字符  
  local identity=""
  if [ "$first_four_chars" = "ADMI" ]; then
      identity="admin"
  elif [ "$first_four_chars" = "User" ]; then
      identity="user"
  else
      identity="unknown"  
  fi

  export FABRIC_CA_CLIENT_HOME=${USER_DIR}
  export FABRIC_CA_CLIENT_TLS_CERTFILES=${ROOT_DIR}/organizations/fabric-ca/${ORG}/crypto/ca-cert.pem
  export FABRIC_CA_CLIENT_MSPDIR=msp
  fabric-ca-client enroll -d -u https://${USER_NAME}:${USER_PW}@localhost:${ORG_CA_PORT} --csr.names OU=${identity}

  # TLS enroll 
  export FABRIC_CA_CLIENT_MSPDIR=tls
  export FABRIC_CA_CLIENT_TLS_CERTFILES=${ROOT_DIR}/organizations/fabric-ca/tls-ca/crypto/tls-cert.pem
  fabric-ca-client enroll -d -u https://${USER_NAME}:${USER_PW}@localhost:7052 \
    --enrollment.profile tls \
    --csr.hosts ${USER_NAME}.${ORG_DOMAIN},localhost


  # 修改私钥名称
  if [ -d "${USER_DIR}/msp/keystore" ]; then
    USER_KEY=$(ls ${USER_DIR}/msp/keystore/*_sk 2>/dev/null | head -n 1)
    if [ -n "$USER_KEY" ] && [ -f "$USER_KEY" ]; then
      mv "$USER_KEY" ${USER_DIR}/msp/keystore/key.pem
      echo "Renamed user key to ${USER_DIR}/msp/keystore/key.pem"
    else
      echo "Warning: User private key not found in ${USER_DIR}/msp/keystore/"
    fi
  else
    echo "Warning: User keystore directory not found: ${USER_DIR}/msp/keystore/"
  fi
  TLS_KEY=$(ls ${USER_DIR}/tls/keystore/*_sk 2>/dev/null | head -n 1)
  if [ -n "$TLS_KEY" ]; then
    mv "$TLS_KEY" ${USER_DIR}/tls/keystore/key.pem
  fi
}
  
# -------------------------------
# 全流程示例
# -------------------------------
runTest() {

  mkdir -p organizations/fabric-ca/{tls-ca,org0,buyer1,supplier1,logistics1,warehouse1,bank1}/crypto
  mkdir -p data/{org0,buyer1,supplier1,logistics1,warehouse1,bank1}/{orderer1,peer1}
  # 设置所有者为当前用户，并确保有写权限
  sudo chown -R $(id -u):$(id -g) data
  chmod -R 775 data
  sudo chown -R $(id -u):$(id -g) organizations
  sudo chmod -R 775 organizations/fabric-ca

  export LOCAL_UID=$(id -u)
  export LOCAL_GID=$(id -g)
  export PATH=$PATH:${ROOT_DIR}/fabric-bin/bin
  export FABRIC_TLS_ORG0=./organizations/ordererOrganizations/org0.example.com/orderers/orderer1-org0.org0.example.com/tls/tlscacerts/tls-localhost-7052.pem
  echo "====1️⃣ Run CA server ===="
  runCAServer

  echo "==== 2️⃣  TLS-CA enroll ===="


  enrollCA "tls-ca-admin" "tls-ca-adminpw" 7052 "tls-ca"  # TLS-CA 注册


  echo "====3️⃣ Init Peers===="
  
  # Orderer Organization
  echo "==== 初始化 Orderer (org0) ===="
  # 为 org0 执行 enrollCA
  enrollCA "rca-org0-admin" "rca-org0-adminpw" 7053 "org0"
  
  # 注册 Orderer 身份到 RCA 和 TLS
  registerMSPIdentity 7053 "orderer1-org0" "ordererPW" "orderer" "org0"
  registerTLSIdentity 7052 "orderer1-org0" "ordererPW" "orderer"

  registerMSPIdentity 7053 "Admin-org0" "org0AdminPW" "admin" "org0"  # 注册 Org Admin
  registerTLSIdentity 7052 "Admin-org0" "org0AdminPW" "admin"
  

  # 初始化 Orderer MSP 和 TLS
  initUser "Admin-org0" "org0AdminPW" 7053 "org0"
  initOrderer "orderer1-org0" "ordererPW" 7053 7052
    # Buyer Organization
  echo "==== 初始化 Buyer1 ===="
  # 为 buyer1 执行 enrollCA
  enrollCA "rca-buyer1-admin" "rca-buyer1-adminpw" 7054 "buyer1"
  # 注册 Buyer 身份到 RCA 和 TLS 
  registerMSPIdentity 7054 "peer1-buyer1" "buyer1PW" "peer" "buyer1"  
  registerMSPIdentity 7054 "Admin-buyer1" "buyer1AdminPW" "admin" "buyer1"
  registerMSPIdentity 7054 "User1-buyer1" "buyer1UserPW" "user" "buyer1"
  # TLS 注册
  registerTLSIdentity 7052 "peer1-buyer1" "buyer1PW" "peer" 
  registerTLSIdentity 7052 "Admin-buyer1" "buyer1AdminPW" "admin"
  registerTLSIdentity 7052 "User1-buyer1" "buyer1UserPW" "user"
 
  initUser "Admin-buyer1" "buyer1AdminPW" 7054 "buyer1"
  initUser "User1-buyer1" "buyer1UserPW" 7054 "buyer1"
  initPeer "peer1-buyer1" "buyer1PW" 7054 7052 "buyer1"
  # Supplier Organization
  echo "==== 初始化 Supplier1 ===="
  # 为 supplier1 执行 enrollCA
  enrollCA "rca-supplier1-admin" "rca-supplier1-adminpw" 7055 "supplier1"
  # 注册 Supplier 身份到 RCA 和 TLS
  registerMSPIdentity 7055 "peer1-supplier1" "supplier1PW" "peer" "supplier1"
  registerMSPIdentity 7055 "Admin-supplier1" "supplier1AdminPW" "admin" "supplier1"
  registerMSPIdentity 7055 "User1-supplier1" "supplier1UserPW" "user" "supplier1"
  registerTLSIdentity 7052 "peer1-supplier1" "supplier1PW" "peer"
  registerTLSIdentity 7052 "Admin-supplier1" "supplier1AdminPW" "admin"
  registerTLSIdentity 7052 "User1-supplier1" "supplier1UserPW" "user"
  
  # 初始化 Supplier1 MSP 和 TLS
  initUser "Admin-supplier1" "supplier1AdminPW" 7055 "supplier1"
  initUser "User1-supplier1" "supplier1UserPW" 7055 "supplier1"
  initPeer "peer1-supplier1" "supplier1PW" 7055 7052 "supplier1"
  
  # Logistics Organization
  echo "==== 初始化 Logistics1 ===="
  # 为 logistics1 执行 enrollCA
  enrollCA "rca-logistics1-admin" "rca-logistics1-adminpw" 7056 "logistics1"
  # 注册 Logistics 身份到 RCA 和 TLS
  registerMSPIdentity 7056 "peer1-logistics1" "logistics1PW" "peer" "logistics1"
  registerMSPIdentity 7056 "Admin-logistics1" "logistics1AdminPW" "admin" "logistics1"
  registerMSPIdentity 7056 "User1-logistics1" "logistics1UserPW" "user" "logistics1"
  registerTLSIdentity 7052 "peer1-logistics1" "logistics1PW" "peer"
  registerTLSIdentity 7052 "Admin-logistics1" "logistics1AdminPW" "admin"
  registerTLSIdentity 7052 "User1-logistics1" "logistics1UserPW" "user"
  # 初始化 Logistics1 MSP 和 TLS
  initUser "Admin-logistics1" "logistics1AdminPW" 7056 "logistics1"
  initUser "User1-logistics1" "logistics1UserPW" 7056 "logistics1"
  initPeer "peer1-logistics1" "logistics1PW" 7056 7052 "logistics1"

  # Warehouse Organization
  echo "==== 初始化 Warehouse1 ===="
  # 为 warehouse1 执行 enrollCA
  enrollCA "rca-warehouse1-admin" "rca-warehouse1-adminpw" 7057 "warehouse1"
  # 注册 Warehouse 身份到 RCA 和 TLS
  registerMSPIdentity 7057 "peer1-warehouse1" "warehouse1PW" "peer" "warehouse1"
  registerMSPIdentity 7057 "Admin-warehouse1" "warehouse1AdminPW" "admin" "warehouse1"
  registerMSPIdentity 7057 "User1-warehouse1" "warehouse1UserPW" "user" "warehouse1"
  registerTLSIdentity 7052 "peer1-warehouse1" "warehouse1PW" "peer"
  registerTLSIdentity 7052 "Admin-warehouse1" "warehouse1AdminPW" "admin"
  registerTLSIdentity 7052 "User1-warehouse1" "warehouse1UserPW" "user"
  
  # 初始化 Warehouse1 MSP 和 TLS
  initUser "Admin-warehouse1" "warehouse1AdminPW" 7057 "warehouse1"
  initUser "User1-warehouse1" "warehouse1UserPW" 7057 "warehouse1"
  initPeer "peer1-warehouse1" "warehouse1PW" 7057 7052 "warehouse1"
  
  # Bank Organization
  echo "==== 初始化 Bank1 ===="
  # 为 bank1 执行 enrollCA
  enrollCA "rca-bank1-admin" "rca-bank1-adminpw" 7058 "bank1"
  # 注册 Bank 身份到 RCA 和 TLS
  registerMSPIdentity 7058 "peer1-bank1" "bank1PW" "peer" "bank1"
  registerMSPIdentity 7058 "Admin-bank1" "bank1AdminPW" "admin" "bank1"
  registerMSPIdentity 7058 "User1-bank1" "bank1UserPW" "user" "bank1"
  registerTLSIdentity 7052 "peer1-bank1" "bank1PW" "peer"
  registerTLSIdentity 7052 "Admin-bank1" "bank1AdminPW" "admin"
  registerTLSIdentity 7052 "User1-bank1" "bank1UserPW" "user"
  
  # 初始化 Bank1 MSP 和 TLS
  initUser "Admin-bank1" "bank1AdminPW" 7058 "bank1"
  initUser "User1-bank1" "bank1UserPW" 7058 "bank1"
  initPeer "peer1-bank1" "bank1PW" 7058 7052 "bank1"

  echo "==== 完成所有组织和节点初始化 ===="

  #给config目录下的脚本添加权限
  find ./config -name "*.sh" -exec chmod +x {} \;  

  echo "====4️⃣ init Genesis ===="
  initGenesis

  echo "====5️⃣ start Peer docker===="
  docker compose -f ./docker/org0/docker-compose-orderer1.yaml up -d
  docker compose -f ./docker/buyer1/docker-compose-buyer1.yaml up -d
  docker compose -f ./docker/logistics1/docker-compose-logistics1.yaml up -d
  docker compose -f ./docker/supplier1/docker-compose-supplier1.yaml up -d
  docker compose -f ./docker/warehouse1/docker-compose-warehouse1.yaml up -d
  docker compose -f ./docker/bank1/docker-compose-bank1.yaml up -d
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  waitFile "./config/changePeer/orderer1-org0-setEnv.sh"
  waitFile "./organizations/ordererOrganizations/org0.example.com/users/Admin-org0@org0.example.com/msp/keystore/key.pem" 
  echo "====6️⃣ create mychannel===="
#  source ${ROOT_DIR}/config/changePeer/orderer1-org0-setEnv.sh

#  osnadmin channel join \
#    --channelID genesis-block \
#    --config-block ./config/channel-artifacts/gen-mychannel.block \
#    --orderer-address localhost:9443 \
#    --ca-file ./organizations/ordererOrganizations/org0.example.com/orderers/orderer1-org0.org0.example.com/tls/tlscacerts/tls-localhost-7052.pem \
#    --client-cert ./organizations/ordererOrganizations/org0.example.com/users/Admin-org0@org0.example.com/tls/signcerts/cert.pem \
#    --client-key ./organizations/ordererOrganizations/org0.example.com/users/Admin-org0@org0.example.com/tls/keystore/key.pem
#  osnadmin channel join --channelID genesis-block --config-block ./config/channel-artifacts/gen-mychannel.block  --orderer-address localhost:9443 --ca-file "./organizations/ordererOrganizations/org0.example.com/orderers/orderer1-org0.org0.example.com/tls/tlscacerts/tls-localhost-7052.pem" --client-cert "./organizations/peerOrganizations/org0.example.com/users/Admin-org0@org0.example.com/msp/signcerts/cert.pem" --client-key "./organizations/peerOrganizations/org0.example.com/users/Admin-org0@org0.example.com/msp/keystore/key.pem"        
  echo ">>>>>>>>>>>>>>>>>osnadmin join channel done"
  echo "====create mychannel===="

  source ./config/changePeer/peer1-buyer1-setEnv.sh
# 创建通道
  peer channel create \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer1-org0.org0.example.com \
    -c mychannel \
    -f ./config/channel-artifacts/channel.tx \
    --outputBlock ./config/channel-artifacts/mychannel.block \
    --cafile ./organizations/ordererOrganizations/org0.example.com/orderers/orderer1-org0.org0.example.com/tls/tlscacerts/tls-localhost-7052.pem \
    --tls  

  echo "====create mychannel Done===="
  echo ">>>>>>>>>>>>>>>create mychannel done"
  echo "====7️⃣ join mychannel===="
  
  PEERS=("peer1-buyer1" "peer1-logistics1" "peer1-supplier1" "peer1-warehouse1" "peer1-bank1")
  
  # 循环让每个 peer 加入通道
  for peer in "${PEERS[@]}"; do
    echo "Joining $peer to channel..."
  
    # 加载对应 peer 的环境变量
    source ./config/changePeer/${peer}-setEnv.sh
  
    # 执行 join
    peer channel join \
      --blockfile ./config/channel-artifacts/mychannel.block \
      --channelID mychannel \
      --orderer localhost:7050 \
      --tls \
      --cafile ./organizations/ordererOrganizations/org0.example.com/orderers/orderer1-org0.org0.example.com/tls/tlscacerts/tls-localhost-7052.pem
  done
  echo "==== 全流程 runTest 完成 ===="
}

down() {
  echo "==== 清理网络与生成资源 (down) 开始 ===="
  # 允许清理过程不中断
  set +e

  # 1) 停止并删除各组织与CA的容器、网络与卷
  echo "- 停止并删除 CA 与各组织容器 (docker compose down)"
  docker compose -f ./docker/ca-tls/docker-compose-ca.yaml down -v --remove-orphans || true
  docker compose -f ./docker/org0/docker-compose-orderer1.yaml down -v --remove-orphans || true
  docker compose -f ./docker/buyer1/docker-compose-buyer1.yaml down -v --remove-orphans || true
  docker compose -f ./docker/logistics1/docker-compose-logistics1.yaml down -v --remove-orphans || true
  docker compose -f ./docker/supplier1/docker-compose-supplier1.yaml down -v --remove-orphans || true
  docker compose -f ./docker/warehouse1/docker-compose-warehouse1.yaml down -v --remove-orphans || true
  docker compose -f ./docker/bank1/docker-compose-bank1.yaml down -v --remove-orphans || true

  # 2) 保险起见，尝试删除可能遗留的链码容器与镜像（可选）
  echo "- 清理可能遗留的链码容器与镜像"
  docker ps -a --filter name=dev- -q | xargs -r docker rm -f || true
  docker images --filter reference='dev-*' -q | xargs -r docker rmi -f || true
  docker volume prune -f
  docker network prune -f
  # 3) 删除生成的通道文件、组织密钥材料与本地数据
  echo "- 删除生成的通道文件与组织目录"
  rm -rf ./config/channel-artifacts/* || true
  sudo rm -rf ./organizations || true
  rm -rf ./data || true

  # 4) 取消设置脚本内导出的环境变量，恢复到初始环境
  echo "- 清理环境变量"
  unset FABRIC_CA_CLIENT_TLS_CERTFILES FABRIC_CA_CLIENT_HOME FABRIC_CA_CLIENT_MSPDIR || true
  unset ORDERER_ADDRESS ORDERER_CA ORDERER_ADMIN_TLS_SIGN_CERT ORDERER_ADMIN_TLS_PRIVATE_KEY || true
  unset FABRIC_TLS_ORG0 CORE_PEER_TLS_ENABLED CORE_PEER_LOCALMSPID CORE_PEER_TLS_ROOTCERT_FILE CORE_PEER_ADDRESS CORE_PEER_MSPCONFIGPATH || true
  unset PROJECT_ROOT || true

  # 恢复严格模式
  set -e
  echo "==== 清理完成，环境已恢复初始状态 ===="
}

ROOT_DIR=${PWD}
FABRIC_CFG_PATH=""
ACTION=""

# 解析命令行参数
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cfgPath)
      FABRIC_CFG_PATH="$2"
      shift 2  # 跳过参数名和它的值
      ;;
    up)
      ACTION="up"
      shift 1
      ;;
    down)
      ACTION="down"
      shift 1
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
done

# 检查动作是否指定
if [ -z "$ACTION" ]; then
  echo "Usage: $0 up --cfgPath <config_dir> | down"
  exit 1
fi

# 仅当 up 时需要 cfgPath
if [ "$ACTION" = "up" ] && [ -z "$FABRIC_CFG_PATH" ]; then
  echo "Error: --cfgPath is required for 'up' and cannot be empty."
  exit 1
fi


export FABRIC_CFG_PATH="$FABRIC_CFG_PATH"

# 动作分发
case "$ACTION" in
  up)
    runTest
    ;;
  down)
    down
    ;;
esac
