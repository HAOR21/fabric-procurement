package contracts

import (
	"SupplyChain/models"
	. "SupplyChain/util"
	"fmt"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type WarehouseContract struct {
	contractapi.Contract
}

// ReceiveLogistics 仓库签收货物
func (s *WarehouseContract) ReceiveLogistics(
	ctx contractapi.TransactionContextInterface,
	receiptID string,
	logisticsID string,
	qualityPassed bool,
	actualTempMin float64,
	actualTempMax float64,
) error {
	if err := IsCallerFromOrgType(ctx, "Warehouse"); err != nil {
		return err
	}

	// 检查收货单是否已存在
	if existing, _ := ctx.GetStub().GetState("RECEIPT_" + receiptID); existing != nil {
		return fmt.Errorf("receipt %s already exists", receiptID)
	}

	// 读取物流单
	logisticsBytes, err := ctx.GetStub().GetState("LOGISTICS_" + logisticsID)
	if err != nil || logisticsBytes == nil {
		return fmt.Errorf("logistics %s not found", logisticsID)
	}
	var logistics models.Logistics
	if err := Deserialize(logisticsBytes, &logistics); err != nil {
		return err
	}

	// 读取水果规格，计算温控与保质合规（需要 ProductID）
	fruitBytes, err := ctx.GetStub().GetState("FRUIT_" + logistics.ProductID)
	if err != nil || fruitBytes == nil {
		return fmt.Errorf("fruit details for %s not found", logistics.ProductID)
	}
	var fruit models.FruitProduct
	if err := Deserialize(fruitBytes, &fruit); err != nil {
		return err
	}

	tempCompliance := true
	if actualTempMin != 0.0 && actualTempMax != 0.0 {
		if actualTempMin < fruit.OptimalTempMin || actualTempMax > fruit.OptimalTempMax {
			tempCompliance = false
		}
	}

	// 判断保质期：根据采摘日期 + ShelfLifeDays 与当前时间比较
	shelfCompliance := true
	if fruit.HarvestDate != "" && fruit.ShelfLifeDays > 0 {
		// 假设 HarvestDate 为 RFC3339 或 YYYY-MM-DD；优先按 RFC3339 解析
		var harvest time.Time
		var perr error
		harvest, perr = time.Parse(time.RFC3339, fruit.HarvestDate)
		if perr != nil {
			harvest, perr = time.Parse("2006-01-02", fruit.HarvestDate)
		}
		if perr == nil {
			expiry := harvest.Add(time.Duration(fruit.ShelfLifeDays) * 24 * time.Hour)
			shelfCompliance = time.Now().UTC().Before(expiry)
		}
	}

	inspection := models.InspectionFailed
	if qualityPassed {
		inspection = models.InspectionPassed
	}

	receipt := models.WarehouseReceipt{
		ReceiptID:             receiptID,
		LogisticsID:           logisticsID,
		OrderID:               logistics.OrderID,
		ProductID:             logistics.ProductID,
		ReceivedKg:            0,
		InspectionResult:      inspection,
		QualityRemarks:        "",
		ReceivedAt:            NowUTC(),
		ReceivedBy:            "",
		TemperatureCompliance: tempCompliance,
		ShelfLifeCompliance:   shelfCompliance,
	}

	rb, err := Serialize(receipt)
	if err != nil {
		return err
	}
	if err := ctx.GetStub().PutState("RECEIPT_"+receiptID, rb); err != nil {
		return fmt.Errorf("failed to put receipt: %v", err)
	}

	return nil
}

// GetFruitProduct 仓库查看水果特性（用于温控和保质期检查）
func (s *WarehouseContract) GetFruitProduct(ctx contractapi.TransactionContextInterface, productID string) (*models.FruitProduct, error) {
	if err := IsCallerFromOrgType(ctx, "Warehouse"); err != nil {
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
