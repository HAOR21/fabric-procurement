#!/bin/bash
set -e

pushd "$(dirname "$BASH_SOURCE")" > /dev/null
OUTPUT_DIR=./channel-artifacts

configtxgen -profile OrdererGenesis -outputBlock "${OUTPUT_DIR}/gen-mychannel.block" -channelID genesis-block
configtxgen -profile ProcurementChannel -outputCreateChannelTx "${OUTPUT_DIR}/channel.tx" -channelID mychannel

popd > /dev/null
