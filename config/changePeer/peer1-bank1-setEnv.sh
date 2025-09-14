#!/bin/bash

pushd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null

export PROJECT_ROOT="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
export PATH=$PROJECT_ROOT/fabric-bin/bin:$PATH
export FABRIC_CFG_PATH=$PROJECT_ROOT/config

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=Bank1MSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PROJECT_ROOT/organizations/peerOrganizations/bank1.example.com/peers/peer1-bank1.bank1.example.com/tls/ca.crt
export CORE_PEER_ADDRESS=peer1-bank1:7051
export CORE_PEER_MSPCONFIGPATH=$PROJECT_ROOT/organizations/peerOrganizations/bank1.example.com/peers/peer1-bank1.bank1.example.com/msp

popd > /dev/null

