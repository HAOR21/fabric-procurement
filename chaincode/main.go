package main

import (
	"SupplyChain/contracts"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

func main() {
	// 初始化子合约
	productContract := new(contracts.ProductContract)
	logisticsContract := new(contracts.LogisticsContract)
	warehouseContract := new(contracts.WarehouseContract)
	bankContract := new(contracts.BankContract)
	supplierContract := new(contracts.SupplierContract)
	buyerContract := new(contracts.BuyerContract)

	// 使用多合约注册方式，避免歧义方法选择
	cc, err := contractapi.NewChaincode(
		productContract,
		logisticsContract,
		warehouseContract,
		bankContract,
		supplierContract,
		buyerContract,
	)
	if err != nil {
		panic(err.Error())
	}

	if err := cc.Start(); err != nil {
		panic(err.Error())
	}
}
