package main

import (
	"log"
	"net"
	"os"

	"SupplyChain/contracts"

	"github.com/hyperledger/fabric-chaincode-go/shim"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
	pb "github.com/hyperledger/fabric-protos-go/peer"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

func main() {
	// 初始化子合约
	productContract := new(contracts.ProductContract)
	logisticsContract := new(contracts.LogisticsContract)
	warehouseContract := new(contracts.WarehouseContract)
	bankContract := new(contracts.BankContract)
	supplierContract := new(contracts.SupplierContract)
	buyerContract := new(contracts.BuyerContract)

	// 使用多合约注册
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

	// 判断是否运行在外部服务模式
	if os.Getenv("CHAINCODE_AS_A_SERVICE") == "true" {
		startExternalServer(cc)
	} else {
		// 传统模式（用于打包部署）
		if err := cc.Start(); err != nil {
			panic(err.Error())
		}
	}
}

// startExternalServer 启动一个外部 gRPC 服务，供 Peer 连接
func startExternalServer(cc *contractapi.ContractChaincode) {
	port := os.Getenv("CHAINCODE_SERVER_PORT")
	if port == "" {
		port = "9999"
	}

	ccid := os.Getenv("CHAINCODE_ID")
	if ccid == "" {
		log.Fatal("必须设置环境变量 CHAINCODE_ID")
	}

	// 创建 gRPC 服务器（无 TLS）
	server := grpc.NewServer(grpc.Creds(insecure.NewCredentials()))

	// 将 ContractChaincode 作为 shim.Chaincode 传入
	// 注意：contractapi.ContractChaincode 实现了 shim.Chaincode 接口
	pb.RegisterChaincodeServer(server, &shim.ChaincodeServer{
		CCID: ccid,
		CC:   cc, // ✅ 这里可以直接传入 *contractapi.ContractChaincode
		TLSProps: shim.TLSProperties{
			Disabled: true,
		},
	})

	lis, err := net.Listen("tcp", ":"+port)
	if err != nil {
		log.Fatalf("监听端口失败: %v", err)
	}

	log.Printf("✅ 外部链码服务启动成功！监听端口: %s，CCID: %s", port, ccid)
	log.Println("👉 现在可以在 GoLand 中打断点调试了！")

	// 启动 gRPC 服务
	if err := server.Serve(lis); err != nil {
		log.Fatalf("gRPC 服务启动失败: %v", err)
	}
}
