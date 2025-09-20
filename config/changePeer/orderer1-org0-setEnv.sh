#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pushd "${SCRIPT_DIR}" > /dev/null

# 项目根目录 - 使用相对路径计算
export PROJECT_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"

# bin 和 config
export PATH=$PROJECT_ROOT/fabric-bin/bin:$PATH
export FABRIC_CFG_PATH=$PROJECT_ROOT/config/core/org0/orderer1-org0

# orderer 节点相关
export ORDERER_CA=$PROJECT_ROOT/organizations/ordererOrganizations/org0.example.com/orderers/orderer1-org0.org0.example.com/tls/ca.crt
export ORDERER_ADMIN_TLS_SIGN_CERT=$PROJECT_ROOT/organizations/ordererOrganizations/org0.example.com/orderers/orderer1-org0.org0.example.com/tls/server.crt
export ORDERER_ADMIN_TLS_PRIVATE_KEY=$PROJECT_ROOT/organizations/ordererOrganizations/org0.example.com/orderers/orderer1-org0.org0.example.com/tls/server.key

# orderer 服务地址
export ORDERER_ADDRESS=orderer1-org0:7050

# export CORE_PEER_TLS_HOSTNAME_OVERRIDE=orderer1-org0.org0.example.com # 告诉 gRPC/TLS 客户端在校验证书时，把目标服务的主机名强制替换为指定的值（例如 peer1-**.**.example.com），从>>而让证书里的 CN/SAN 和实际连接的地址（如 localhost:port）对得上。

popd > /dev/null

