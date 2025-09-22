package contracts

import (
	"SupplyChain/config"
	"SupplyChain/models"
	. "SupplyChain/util"
	"encoding/json"
	"fmt"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type ProductContract struct {
	contractapi.Contract
}

// CreateFruitProduct 创建新鲜水果商品（公开 + 私有属性）
func (s *ProductContract) CreateFruitProduct(
	ctx contractapi.TransactionContextInterface,
	productID string,
	name string,
	description string,
	fruitTypeStr string, // 如 "APPLE"
	sku string,
	origin string,
	harvestDate string,
	// 注意：以下参数可选，若为0或空则使用默认值
	shelfLifeDays int,
	optimalTempMin float64,
	optimalTempMax float64,
	optimalHumidityMin float64,
	optimalHumidityMax float64,
	sugarLevel float64,
	certificationsJSON string, // 传 JSON 字符串：["有机","绿色"]
	variety string,
	weightPerUnit float64,
	pricePerKg float64,
	costPerKg float64,
	supplierBatch string,
	farmID string,
) error {
	// 权限检查
	if err := IsCallerFromOrgType(ctx, "Supplier"); err != nil {
		return err
	}
	// 检查水果类型
	fruitType := models.FruitType(fruitTypeStr)
	if !fruitType.IsValid() {
		return fmt.Errorf("invalid fruit type: %s, allowed: %v", fruitTypeStr, models.AllFruitTypes())
	}

	// 若 Product 不存在则创建（设置 Type=FRUIT）
	existingProductBytes, err := ctx.GetStub().GetState(productID)
	if err != nil {
		return fmt.Errorf("failed to read product: %v", err)
	}
	if existingProductBytes == nil {
		mspID, err := ctx.GetClientIdentity().GetMSPID()
		if err != nil {
			return err
		}
		product := models.Product{
			ProductID:   productID,
			Name:        name,
			Description: description,
			SKU:         sku,
			CreatedBy:   mspID,
			CreatedAt:   NowUTC(),
			Type:        "FRUIT",
		}
		pb, err := Serialize(product)
		if err != nil {
			return err
		}
		if err := ctx.GetStub().PutState(productID, pb); err != nil {
			return fmt.Errorf("failed to put product: %v", err)
		}
	}

	// === 创建 FruitProduct 并应用默认特性 ===
	Fruit := models.FruitProduct{
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

	// 解析 certifications
	var certs []string
	if certificationsJSON != "" {
		if err := json.Unmarshal([]byte(certificationsJSON), &certs); err != nil {
			return fmt.Errorf("invalid certifications JSON: %v", err)
		}
	}
	Fruit.Certifications = certs

	// 🎯 关键：应用该水果类型的默认特性（未设置的字段）
	if err := Fruit.ApplyDefaultSpec(fruitType); err != nil {
		return fmt.Errorf("failed to apply default spec: %v", err)
	}

	// 序列化并保存...
	FruitBytes, err := Serialize(Fruit)
	if err != nil {
		return err
	}
	if err := ctx.GetStub().PutState("FRUIT_"+productID, FruitBytes); err != nil {
		return fmt.Errorf("failed to put fresh fruit details: %v", err)
	}

	// === 3. 创建水果私有属性 ===
	FruitPrivate := models.FruitPrivate{
		ProductID:     productID,
		PricePerKg:    pricePerKg,
		CostPerKg:     costPerKg,
		SupplierBatch: supplierBatch,
		FarmID:        farmID,
	}

	privateBytes, err := Serialize(FruitPrivate)
	if err != nil {
		return err
	}
	// 存入 collectionBuyerBankSupplier
	if err := ctx.GetStub().PutPrivateData(config.CollectionBuyerBankSupplier, "FRUIT_PRIVATE_"+productID, privateBytes); err != nil {
		return fmt.Errorf("failed to put private  fruit data: %v", err)
	}

	return nil
}

// GetFruitProduct 获取水果商品完整信息（公开部分）
func (s *ProductContract) GetFruitProduct(ctx contractapi.TransactionContextInterface, productID string) (*models.FruitFull, error) {
	// 获取通用商品信息
	product, err := s.GetProduct(ctx, productID)
	if err != nil {
		return nil, err
	}

	// 获取水果专属信息
	FruitBytes, err := ctx.GetStub().GetState("FRUIT_" + productID)
	if err != nil {
		return nil, fmt.Errorf("failed to read  fruit details: %v", err)
	}
	if FruitBytes == nil {
		return nil, fmt.Errorf(" fruit details for %s not found", productID)
	}

	var Fruit models.FruitProduct
	if err := Deserialize(FruitBytes, &Fruit); err != nil {
		return nil, err
	}

	// 组合返回
	return &models.FruitFull{
		Product: *product,
		Fruit:   Fruit,
	}, nil
}

// GetFruitPrivate 获取水果私有信息（价格、成本等）
func (s *ProductContract) GetFruitPrivate(ctx contractapi.TransactionContextInterface, productID string) (*models.FruitPrivate, error) {
	// 权限：Buyer + Bank + Supplier
	allowedOrgs := []string{"Buyer", "Bank", "Supplier"}
	if err := IsCallerFromAnyOrg(ctx, allowedOrgs); err != nil {
		return nil, err
	}

	privateBytes, err := ctx.GetStub().GetPrivateData(config.CollectionBuyerBankSupplier, "FRUIT_PRIVATE_"+productID)
	if err != nil {
		return nil, fmt.Errorf("failed to read private  fruit data: %v", err)
	}
	if privateBytes == nil {
		return nil, fmt.Errorf("private data for  fruit %s not found", productID)
	}

	var FruitPrivate models.FruitPrivate
	if err := Deserialize(privateBytes, &FruitPrivate); err != nil {
		return nil, err
	}

	return &FruitPrivate, nil
}

// GetFruitFull 获取完整水果商品信息（公开+私有）
func (s *ProductContract) GetFruitFull(ctx contractapi.TransactionContextInterface, productID string) (*models.FruitFull, error) {
	full, err := s.GetFruitProduct(ctx, productID)
	if err != nil {
		return nil, err
	}

	// 尝试获取私有数据（无权限时不报错，返回 nil）
	private, _ := s.GetFruitPrivate(ctx, productID)
	if private != nil {
		full.FruitPrivate = *private
	}

	return full, nil
}

// GetProduct 获取公开商品信息
func (s *ProductContract) GetProduct(ctx contractapi.TransactionContextInterface, productID string) (*models.Product, error) {
	productBytes, err := ctx.GetStub().GetState(productID)
	if err != nil {
		return nil, fmt.Errorf("failed to read product: %v", err)
	}
	if productBytes == nil {
		return nil, fmt.Errorf("product %s does not exist", productID)
	}

	var product models.Product
	if err := Deserialize(productBytes, &product); err != nil {
		return nil, err
	}
	return &product, nil
}
