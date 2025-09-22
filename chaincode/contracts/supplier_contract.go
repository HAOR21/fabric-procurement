package contracts

import (
	"SupplyChain/config"
	"SupplyChain/models"
	. "SupplyChain/util"
	"encoding/json"
	"fmt"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type SupplierContract struct {
	contractapi.Contract
}

// CreateFruitProduct 创建水果商品（公开 + 私有）
func (s *SupplierContract) CreateFruitProduct(
	ctx contractapi.TransactionContextInterface,
	productID string,
	name string,
	description string,
	sku string,
	fruitTypeStr string,
	origin string,
	harvestDate string,
	shelfLifeDays int,
	optimalTempMin float64,
	optimalTempMax float64,
	optimalHumidityMin float64,
	optimalHumidityMax float64,
	sugarLevel float64,
	certificationsJSON string,
	variety string,
	weightPerUnit float64,
	pricePerKg float64,
	costPerKg float64,
	supplierBatch string,
	farmID string,
) error {
	// 权限：仅 Supplier
	if err := IsCallerFromOrgType(ctx, "Supplier"); err != nil {
		return err
	}

	// 检查商品是否已存在
	if existing, _ := ctx.GetStub().GetState(productID); existing != nil {
		return fmt.Errorf("product %s already exists", productID)
	}

	mspID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return err
	}

	// 创建通用商品信息
	product := models.Product{
		ProductID:   productID,
		Name:        name,
		Description: description,
		SKU:         sku,
		CreatedBy:   mspID,
		CreatedAt:   NowUTC(),
		Type:        "FRUIT",
	}

	productBytes, err := Serialize(product)
	if err != nil {
		return err
	}
	if err := ctx.GetStub().PutState(productID, productBytes); err != nil {
		return fmt.Errorf("failed to put product: %v", err)
	}

	// 创建水果专属信息
	fruitType := models.FruitType(fruitTypeStr)
	if !fruitType.IsValid() {
		return fmt.Errorf("invalid fruit type: %s", fruitTypeStr)
	}

	fruitProduct := models.FruitProduct{
		ProductID:          productID,
		FruitType:          fruitType,
		Origin:             origin,
		HarvestDate:        harvestDate,
		ShelfLifeDays:      shelfLifeDays,
		OptimalTempMin:     optimalTempMin,
		OptimalTempMax:     optimalTempMax,
		OptimalHumidityMin: optimalHumidityMin,
		OptimalHumidityMax: optimalHumidityMax,
		SugarLevel:         sugarLevel,
		Variety:            variety,
		WeightPerUnit:      weightPerUnit,
	}

	// 应用默认特性（如果未设置）
	if err := fruitProduct.ApplyDefaultSpec(fruitType); err != nil {
		return err
	}

	// 解析 certifications
	if certificationsJSON != "" {
		var certs []string
		if err := json.Unmarshal([]byte(certificationsJSON), &certs); err != nil {
			return fmt.Errorf("invalid certifications JSON: %v", err)
		}
		fruitProduct.Certifications = certs
	}

	fruitBytes, err := Serialize(fruitProduct)
	if err != nil {
		return err
	}
	if err := ctx.GetStub().PutState("FRUIT_"+productID, fruitBytes); err != nil {
		return fmt.Errorf("failed to put fruit details: %v", err)
	}

	// 创建私有数据
	fruitPrivate := models.FruitPrivate{
		ProductID:     productID,
		PricePerKg:    pricePerKg,
		CostPerKg:     costPerKg,
		SupplierBatch: supplierBatch,
		FarmID:        farmID,
	}

	privateBytes, err := Serialize(fruitPrivate)
	if err != nil {
		return err
	}
	if err := ctx.GetStub().PutPrivateData(config.CollectionBuyerBankSupplier, "FRUIT_PRIVATE_"+productID, privateBytes); err != nil {
		return fmt.Errorf("failed to put private data: %v", err)
	}

	return nil
}

// GetProduct 供应商可查看自己创建的商品
func (s *SupplierContract) GetProduct(ctx contractapi.TransactionContextInterface, productID string) (*models.Product, error) {
	if err := IsCallerFromOrgType(ctx, "Supplier"); err != nil {
		return nil, err
	}
	productBytes, err := ctx.GetStub().GetState(productID)
	if err != nil {
		return nil, fmt.Errorf("failed to read product: %v", err)
	}
	if productBytes == nil {
		return nil, fmt.Errorf("product %s not found", productID)
	}
	var product models.Product
	if err := Deserialize(productBytes, &product); err != nil {
		return nil, err
	}
	return &product, nil
}

func (s *SupplierContract) ConfirmOrder(ctx contractapi.TransactionContextInterface, orderID string) error {
	if err := IsCallerFromOrgType(ctx, "Supplier"); err != nil {
		return err
	}

	// 获取公开订单
	orderBytes, err := ctx.GetStub().GetState(orderID)
	if err != nil || orderBytes == nil {
		return fmt.Errorf("order %s not found", orderID)
	}

	var order models.PurchaseOrder
	if err := Deserialize(orderBytes, &order); err != nil {
		return err
	}

	if order.Status != models.StatusCreated {
		return fmt.Errorf("order must be in CREATED status to confirm")
	}

	// 获取私有订单明细（验证价格）
	privateBytes, err := ctx.GetStub().GetPrivateData(config.CollectionBuyerBankSupplier, "ORDER_PRIVATE_"+orderID)
	if err != nil || privateBytes == nil {
		return fmt.Errorf("private order details not found")
	}

	var orderPrivate models.PurchaseOrderPrivate
	if err := Deserialize(privateBytes, &orderPrivate); err != nil {
		return err
	}

	mspID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return err
	}

	order.Status = models.StatusConfirmed
	order.SupplierID = mspID
	order.ConfirmedAt = NowUTC()

	orderBytes, err = Serialize(order)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState(orderID, orderBytes)
}
