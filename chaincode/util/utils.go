package util

import (
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// IsCallerFromOrgType 检查调用者 MSPID 是否以指定组织类型前缀开头（如 "Buyer", "Supplier" 等）
func IsCallerFromOrgType(ctx contractapi.TransactionContextInterface, orgType string) error {
	clientMSPID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return fmt.Errorf("failed to get MSPID: %v", err)
	}

	if !strings.HasPrefix(clientMSPID, orgType) {
		return fmt.Errorf("access denied: caller %s is not a %s organization", clientMSPID, orgType)
	}

	return nil
}

// 检查调用者是否属于指定组织
func IsCallerFromOrg(ctx contractapi.TransactionContextInterface, expectedOrg string) error {
	clientMSPID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return fmt.Errorf("failed to get MSPID: %v", err)
	}
	if clientMSPID != expectedOrg {
		return fmt.Errorf("access denied: caller is %s, expected %s", clientMSPID, expectedOrg)
	}
	return nil
}

// 检查调用者是否属于多个允许组织之一
func IsCallerFromAnyOrg(ctx contractapi.TransactionContextInterface, allowedOrgs []string) error {
	clientMSPID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return fmt.Errorf("failed to get MSPID: %v", err)
	}
	for _, org := range allowedOrgs {
		if strings.HasPrefix(clientMSPID, org) {
			return nil
		}
	}
	return fmt.Errorf("access denied: caller %s not in allowed orgs %v", clientMSPID, allowedOrgs)
}

// 序列化结构体为 JSON 字节数组
func Serialize(data interface{}) ([]byte, error) {
	bytes, err := json.Marshal(data)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal: %v", err)
	}
	return bytes, nil
}

// 反序列化 JSON 字节数组到结构体
func Deserialize(data []byte, target interface{}) error {
	if data == nil {
		return fmt.Errorf("data is nil")
	}
	err := json.Unmarshal(data, target)
	if err != nil {
		return fmt.Errorf("failed to unmarshal: %v", err)
	}
	return nil
}

// 创建复合键（用于一对多关系）
func CreateCompositeKey(ctx contractapi.TransactionContextInterface, objectType string, attributes []string) (string, error) {
	compositeKey, err := ctx.GetStub().CreateCompositeKey(objectType, attributes)
	if err != nil {
		return "", fmt.Errorf("failed to create composite key: %v", err)
	}
	return compositeKey, nil
}

func NowUTC() string {
	return time.Now().UTC().Format(time.RFC3339)
}
