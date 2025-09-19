#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pushd "${SCRIPT_DIR}" > /dev/null

# 项目根目录 - 使用相对路径计算
export PROJECT_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"

export PATH=$PROJECT_ROOT/fabric-bin/bin:$PATH
export FABRIC_CFG_PATH=$PROJECT_ROOT/config/core/logistics1/peer1-logistics1

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=Logistics1MSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PROJECT_ROOT/organizations/peerOrganizations/logistics1.example.com/peers/peer1-logistics1.logistics1.example.com/tls/tlscacerts/tls-localhost-7052.pem
export CORE_PEER_ADDRESS=localhost:9051
export CORE_PEER_MSPCONFIGPATH=$PROJECT_ROOT/organizations/peerOrganizations/logistics1.example.com/users/Admin-logistics1@logistics1.example.com/msp #这里需要指向具体身份的MSp文件来>表明客户端的身份


popd > /dev/null

