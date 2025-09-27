package main

import (
    "fmt"
    "log"
    "net"

    "github.com/hyperledger/fabric-chaincode-go/shim"
    pb "github.com/hyperledger/fabric-protos-go/peer"
)

// SimpleChaincode implements the Chaincode interface
type SimpleChaincode struct{}

// Init function
func (t *SimpleChaincode) Init(stub shim.ChaincodeStubInterface) pb.Response {
    return shim.Success(nil)
}

// Invoke function
func (t *SimpleChaincode) Invoke(stub shim.ChaincodeStubInterface) pb.Response {
    function, args := stub.GetFunctionAndParameters()
    if function == "ping" {
        return shim.Success([]byte("pong"))
    }
    return shim.Error("Unknown function: " + function)
}

func main() {
    cc := new(SimpleChaincode)

    // 指定 gRPC 地址，与 connection.json 中一致
    grpcAddress := "0.0.0.0:9999"

    log.Printf("Starting external chaincode at %s", grpcAddress)
    lis, err := net.Listen("tcp", grpcAddress)
    if err != nil {
        log.Fatalf("Failed to listen: %v", err)
    }

    err = shim.StartExternalChaincode(cc, grpcAddress)
    if err != nil {
        log.Fatalf("Error starting chaincode: %v", err)
    }

    fmt.Println("Chaincode service started")
}

