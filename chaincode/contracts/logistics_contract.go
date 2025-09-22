package contracts

import (
	"SupplyChain/config"
	"SupplyChain/models"
	. "SupplyChain/util"
	"fmt"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type LogisticsContract struct {
	contractapi.Contract
}

// CreateLogistics 物流创建运输单
func (s *LogisticsContract) CreateLogistics(
	ctx contractapi.TransactionContextInterface,
	logisticsID string,
	orderID string,
	from string,
	to string,
) error {
	if err := IsCallerFromOrgType(ctx, "Logistics"); err != nil {
		return err
	}

	// 检查运输单是否已存在
	if existing, _ := ctx.GetStub().GetState("LOGISTICS_" + logisticsID); existing != nil {
		return fmt.Errorf("logistics %s already exists", logisticsID)
	}

	// 读取订单，填充 ProductID 并可校验订单状态是否已确认
	orderBytes, err := ctx.GetStub().GetState(orderID)
	if err != nil || orderBytes == nil {
		return fmt.Errorf("order %s not found", orderID)
	}
	var order models.PurchaseOrder
	if err := Deserialize(orderBytes, &order); err != nil {
		return err
	}
	if order.Status != models.StatusConfirmed {
		return fmt.Errorf("order %s not confirmed", orderID)
	}

	// 创建公开物流单
	logistics := models.Logistics{
		LogisticsID: logisticsID,
		OrderID:     orderID,
		ProductID:   order.ProductID,
		From:        from,
		To:          to,
		Status:      "PENDING",
		CreatedAt:   NowUTC(),
	}

	logisticsBytes, err := Serialize(logistics)
	if err != nil {
		return err
	}
	if err := ctx.GetStub().PutState("LOGISTICS_"+logisticsID, logisticsBytes); err != nil {
		return fmt.Errorf("failed to put logistics: %v", err)
	}

	// 初始化私有温控/轨迹集合（可选为空）
	private := models.LogisticsPrivate{LogisticsID: logisticsID}
	privateBytes, err := Serialize(private)
	if err != nil {
		return err
	}
	if err := ctx.GetStub().PutPrivateData(config.CollectionBuyerWarehouseLogistics, "LOGISTICS_PRIVATE_"+logisticsID, privateBytes); err != nil {
		return fmt.Errorf("failed to init logistics private: %v", err)
	}
	return nil
}

// UpdateLogisticsStatus 更新运输状态
func (s *LogisticsContract) UpdateLogisticsStatus(
	ctx contractapi.TransactionContextInterface,
	logisticsID string,
	status string,
	location string,
	temperature *float64,
) error {
	if err := IsCallerFromOrgType(ctx, "Logistics"); err != nil {
		return err
	}

	// 读取公开物流单
	bytes, err := ctx.GetStub().GetState("LOGISTICS_" + logisticsID)
	if err != nil || bytes == nil {
		return fmt.Errorf("logistics %s not found", logisticsID)
	}
	var logistics models.Logistics
	if err := Deserialize(bytes, &logistics); err != nil {
		return err
	}

	// 更新状态与位置（校验枚举）
	newStatus := models.LogisticsStatus(status)
	switch newStatus {
	case "PENDING", "IN_TRANSIT", "TEMPERATURE_ALERT", "DELIVERED", "EXCEPTION":
		// ok
	default:
		return fmt.Errorf("invalid logistics status: %s", status)
	}
	logistics.Status = newStatus
	logistics.CurrentLocation = location
	logistics.UpdatedAt = NowUTC()

	bytes, err = Serialize(logistics)
	if err != nil {
		return err
	}
	if err := ctx.GetStub().PutState("LOGISTICS_"+logisticsID, bytes); err != nil {
		return fmt.Errorf("failed to update logistics: %v", err)
	}

	// 温度记录追加到私有集合：读取水果阈值并判定 IsAlert
	// 获取商品以取得阈值
	if temperature != nil {
		// 通过物流单反查商品
		fruitBytes, err := ctx.GetStub().GetState("FRUIT_" + logistics.ProductID)
		if err == nil && fruitBytes != nil {
			var fruit models.FruitProduct
			if Deserialize(fruitBytes, &fruit) == nil {
				isAlert := (*temperature < fruit.OptimalTempMin) || (*temperature > fruit.OptimalTempMax)

				// 读取现有私有数据
				privBytes, _ := ctx.GetStub().GetPrivateData(config.CollectionBuyerWarehouseLogistics, "LOGISTICS_PRIVATE_"+logisticsID)
				var priv models.LogisticsPrivate
				if privBytes != nil {
					_ = Deserialize(privBytes, &priv)
				} else {
					priv = models.LogisticsPrivate{LogisticsID: logisticsID}
				}

				// 追加温度日志
				priv.TemperatureLog = append(priv.TemperatureLog, models.TemperatureLog{
					Timestamp:   NowUTC(),
					Temperature: *temperature,
					MinAllowed:  fruit.OptimalTempMin,
					MaxAllowed:  fruit.OptimalTempMax,
					IsAlert:     isAlert,
				})

				// 保存回私有集合
				privBytes, err = Serialize(priv)
				if err == nil {
					_ = ctx.GetStub().PutPrivateData(config.CollectionBuyerWarehouseLogistics, "LOGISTICS_PRIVATE_"+logisticsID, privBytes)
				}
			}
		}
	}
	return nil
}
