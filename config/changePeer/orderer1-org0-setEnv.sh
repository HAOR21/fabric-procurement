#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pushd "${SCRIPT_DIR}" > /dev/null

# 项目根目录 - 使用相对路径计算
export PROJECT_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"

# bin 和 config
export PATH=$PROJECT_ROOT/fabric-bin/bin:$PATH
export FABRIC_CFG_PATH=$PROJECT_ROOT/config/core/org0/orderer1-org0

# orderer 节点相关
export ORDERER_CA=$PROJECT_ROOT/organizations/ordererOrganizations/org0.example.com/orderers/orderer1-org0.org0.example.com/tls/tlscacerts/tls-localhost-7052.pem
export ORDERER_ADMIN_TLS_SIGN_CERT=$PROJECT_ROOT/organizations/ordererOrganizations/org0.example.com/orderers/orderer1-org0.org0.example.com/tls/signcerts/cert.pem
export ORDERER_ADMIN_TLS_PRIVATE_KEY=$PROJECT_ROOT/organizations/ordererOrganizations/org0.example.com/orderers/orderer1-org0.org0.example.com/tls/keystore/key.pem

# orderer 服务地址
export ORDERER_ADDRESS=localhost:7050

popd > /dev/null

