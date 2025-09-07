#!/bin/bash

pushd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null

# 项目根目录
export PROJECT_ROOT="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"

# peer 二进制路径
export PATH=$PROJECT_ROOT/fabric-bin/bin:$PATH

# 配置文件路径
export FABRIC_CFG_PATH=$PROJECT_ROOT/config

# peer 环境变量
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=buyer1MSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PROJECT_ROOT/organizations/peerOrganizations/buyer1.example.com/peers/peer1.buyer1.example.com/tls/ca.crt
export CORE_PEER_ADDRESS=peer1-buyer1:7051
export CORE_PEER_MSPCONFIGPATH=$PROJECT_ROOT/organizations/peerOrganizations/buyer1.example.com/peers/peer1.buyer1.example.com/msp

popd > /dev/null

