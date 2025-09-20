#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pushd "${SCRIPT_DIR}" > /dev/null

# 项目根目录 - 使用相对路径计算
export PROJECT_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"

export PATH=$PROJECT_ROOT/fabric-bin/bin:$PATH
export FABRIC_CFG_PATH=$PROJECT_ROOT/config/core/bank1/peer1-bank1

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=Bank1MSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PROJECT_ROOT/organizations/peerOrganizations/bank1.example.com/peers/peer1-bank1.bank1.example.com/tls/ca.crt
export CORE_PEER_ADDRESS=peer1-bank1:8051
export CORE_PEER_MSPCONFIGPATH=$PROJECT_ROOT/organizations/peerOrganizations/bank1.example.com/users/Admin-bank1@bank1.example.com/msp #这里需要指向具体身份的MSp文件来表明客户端的身份

popd > /dev/null

