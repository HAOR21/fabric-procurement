#!/bin/bash

pushd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null

# 项目根目录
export PROJECT_ROOT="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"

# bin 和 config
export PATH=$PROJECT_ROOT/fabric-bin/bin:$PATH
export FABRIC_CFG_PATH=$PROJECT_ROOT/config

# orderer 节点相关
export ORDERER_CA=$PROJECT_ROOT/organizations/ordererOrganizations/org0/orderers/orderer1-org0/tls/ca.crt
export ORDERER_ADMIN_TLS_SIGN_CERT=$PROJECT_ROOT/organizations/ordererOrganizations/org0/orderers/orderer1-org0/tls/signcerts/cert.pem
export ORDERER_ADMIN_TLS_PRIVATE_KEY=$PROJECT_ROOT/organizations/ordererOrganizations/org0/orderers/orderer1-org0/tls/keystore/key.pem

# orderer 服务地址
export ORDERER_ADDRESS=orderer1-org0:7050

popd > /dev/null

