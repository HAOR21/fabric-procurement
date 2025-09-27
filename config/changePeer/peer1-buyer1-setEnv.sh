#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pushd "${SCRIPT_DIR}" > /dev/null

# 项目根目录 - 使用相对路径计算
export PROJECT_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"
# peer 二进制路径
export PATH=$PROJECT_ROOT/fabric-bin/bin:$PATH

# 配置文件路径
export FABRIC_CFG_PATH=$PROJECT_ROOT/config/core/buyer1/peer1-buyer1

# peer 环境变量
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=Buyer1MSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PROJECT_ROOT/organizations/peerOrganizations/buyer1.example.com/peers/peer1-buyer1.buyer1.example.com/tls/ca.crt
export CORE_PEER_ADDRESS=peer1-buyer1:7051
export CORE_CHAINCODE_EXTERNALSERVICE=true #开启 链码即服务模式 
export CORE_CHAINCODE_EXECUTETIMEOUT=300s 
export CORE_CHAINCODE_EXTERNALBUILDERS=[] #禁用本地构建器（peer 不需要自己 build 代码） 
export CORE_CHAINCODE_ADDRESSAUTODETECT=true #自动检测 peer 和链码进程之间的 反向通信地址
export CORE_PEER_MSPCONFIGPATH=$PROJECT_ROOT/organizations/peerOrganizations/buyer1.example.com/users/Admin-buyer1@buyer1.example.com/msp #这里需要指向具体身份的MSp文件来>表明客户端的身份


popd > /dev/null

