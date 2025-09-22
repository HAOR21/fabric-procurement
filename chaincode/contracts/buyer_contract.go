package contracts

import (
	"SupplyChain/config"
	"SupplyChain/models"
	. "SupplyChain/util"
	"fmt"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type BuyerContract struct {
	contractapi.Contract
}

func (s *BuyerContract) CreatePurchaseOrder(
	ctx contractapi.TransactionContextInterface,
	orderID string,
	productID string,
	quantityKg float64,
	deliveryDate string,
) error {
	if err := IsCallerFromOrgType(ctx, "Buyer"); err != nil {
		return err
	}

	// 校验参数
	if quantityKg <= 0 {
		return fmt.Errorf("quantityKg must be > 0")
	}

	// 检查重复订单键
	if existing, _ := ctx.GetStub().GetState(orderID); existing != nil {
		return fmt.Errorf("order %s already exists", orderID)
	}

	// 检查商品是否存在
	if prod, _ := ctx.GetStub().GetState(productID); prod == nil {
		return fmt.Errorf("product %s not found", productID)
	}

	// 获取私有价格
	privateBytes, err := ctx.GetStub().GetPrivateData(config.CollectionBuyerBankSupplier, "FRUIT_PRIVATE_"+productID)
	if err != nil || privateBytes == nil {
		return fmt.Errorf("private data for product %s not found", productID)
	}

	var fruitPrivate models.FruitPrivate
	if err := Deserialize(privateBytes, &fruitPrivate); err != nil {
		return err
	}

	mspID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return err
	}

	// 创建公开订单头（不含价格）
	order := models.PurchaseOrder{
		OrderID:      orderID,
		BuyerID:      mspID,
		ProductID:    productID,
		QuantityKg:   quantityKg,
		DeliveryDate: deliveryDate,
		Status:       models.StatusCreated,
		CreatedAt:    NowUTC(),
	}

	orderBytes, err := Serialize(order)
	if err != nil {
		return err
	}
	if err := ctx.GetStub().PutState(orderID, orderBytes); err != nil {
		return err
	}

	// 创建私有订单明细（含价格）
	orderPrivate := models.PurchaseOrderPrivate{
		OrderID:     orderID,
		UnitPrice:   fruitPrivate.PricePerKg,
		TotalAmount: quantityKg * fruitPrivate.PricePerKg,
		Currency:    "CNY",
	}

	privateBytes, err = Serialize(orderPrivate)
	if err != nil {
		return err
	}
	// 存入 collectionBuyerBankSupplier
	return ctx.GetStub().PutPrivateData(config.CollectionBuyerBankSupplier, "ORDER_PRIVATE_"+orderID, privateBytes)
}

// GetOrder 获取订单
func (s *BuyerContract) GetOrder(ctx contractapi.TransactionContextInterface, orderID string) (*models.PurchaseOrder, error) {
	if err := IsCallerFromAnyOrg(ctx, []string{"Buyer", "Supplier"}); err != nil {
		return nil, err
	}
	orderBytes, err := ctx.GetStub().GetState(orderID)
	if err != nil {
		return nil, fmt.Errorf("failed to read order: %v", err)
	}
	if orderBytes == nil {
		return nil, fmt.Errorf("order %s does not exist", orderID)
	}
	var order models.PurchaseOrder
	if err := Deserialize(orderBytes, &order); err != nil {
		return nil, err
	}
	return &order, nil
}

// GetOrderHistory 获取订单变更历史（审计用）
func (s *BuyerContract) GetOrderHistory(ctx contractapi.TransactionContextInterface, orderID string) ([]*models.OrderHistoryRecord, error) {
	if err := IsCallerFromAnyOrg(ctx, []string{"Buyer", "Supplier"}); err != nil {
		return nil, err
	}
	historyIter, err := ctx.GetStub().GetHistoryForKey(orderID)
	if err != nil {
		return nil, fmt.Errorf("failed to get history: %v", err)
	}
	defer historyIter.Close()

	var records []*models.OrderHistoryRecord
	for historyIter.HasNext() {
		modification, err := historyIter.Next()
		if err != nil {
			return nil, err
		}
		var order models.PurchaseOrder
		if modification.Value != nil {
			_ = Deserialize(modification.Value, &order)
		}
		record := models.OrderHistoryRecord{
			TxID:      modification.TxId,
			Timestamp: modification.Timestamp.AsTime().Format(time.RFC3339),
			IsDeleted: modification.IsDelete,
			Order:     order,
		}
		records = append(records, &record)
	}
	return records, nil
}

// GetFruitProduct 买家查看水果公开信息
func (s *BuyerContract) GetFruitProduct(ctx contractapi.TransactionContextInterface, productID string) (*models.FruitProduct, error) {
	if err := IsCallerFromOrgType(ctx, "Buyer"); err != nil {
		return nil, err
	}

	fruitBytes, err := ctx.GetStub().GetState("FRUIT_" + productID)
	if err != nil {
		return nil, fmt.Errorf("failed to read fruit details: %v", err)
	}
	if fruitBytes == nil {
		return nil, fmt.Errorf("fruit details for %s not found", productID)
	}

	var fruit models.FruitProduct
	if err := Deserialize(fruitBytes, &fruit); err != nil {
		return nil, err
	}
	return &fruit, nil
}

// GetFruitPrivate 买家查看私有价格
func (s *BuyerContract) GetFruitPrivate(ctx contractapi.TransactionContextInterface, productID string) (*models.FruitPrivate, error) {
	if err := IsCallerFromOrgType(ctx, "Buyer"); err != nil {
		return nil, err
	}

	privateBytes, err := ctx.GetStub().GetPrivateData(config.CollectionBuyerBankSupplier, "FRUIT_PRIVATE_"+productID)
	if err != nil {
		return nil, fmt.Errorf("failed to read private data: %v", err)
	}
	if privateBytes == nil {
		return nil, fmt.Errorf("private data for %s not found", productID)
	}

	var private models.FruitPrivate
	if err := Deserialize(privateBytes, &private); err != nil {
		return nil, err
	}
	return &private, nil
}
