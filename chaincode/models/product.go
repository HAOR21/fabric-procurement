package models

// ============ 通用商品结构（所有商品都有的基础信息） ============
type Product struct {
	ProductID   string `json:"productID"`
	Name        string `json:"name"`        // 如 "红富士苹果"
	Description string `json:"description"` // 如 "山东烟台产地，有机认证"
	SKU         string `json:"sku"`         // "FRUIT-APPLE-REDFUJI-2025"
	CreatedBy   string `json:"createdBy"`   // "Supplier1MSP"
	CreatedAt   string `json:"createdAt"`   // ISO8601
	Type        string `json:"type"`        // "FRUIT" 标记类型，便于查询
}

// ============ 新鲜水果专属公开属性 ============
type FruitProduct struct {
	ProductID          string    `json:"productID"` // 关联 Product
	FruitType          FruitType `json:"fruitType"`
	Origin             string    `json:"origin"`             // 产地，如 "山东烟台"
	HarvestDate        string    `json:"harvestDate"`        // 采摘日期，如 "2025-04-01"
	ShelfLifeDays      int       `json:"shelfLifeDays"`      // 保质期（天），如 15  → 可继承或覆盖默认值
	OptimalTempMin     float64   `json:"optimalTempMin"`     // 最佳存储温度下限，如 2.0
	OptimalTempMax     float64   `json:"optimalTempMax"`     // 最佳存储温度上限，如 6.0
	OptimalHumidityMin float64   `json:"optimalHumidityMin"` // 最佳湿度下限 (%) → 可继承默认
	OptimalHumidityMax float64   `json:"optimalHumidityMax"` // 最佳湿度上限 (%) → 可继承默认
	SugarLevel         float64   `json:"sugarLevel"`         // 实测糖度（Brix），如 14.5
	Certifications     []string  `json:"certifications"`     // 认证，如 ["有机", "绿色食品"]
	Variety            string    `json:"variety"`            // 品种，如 "红富士"
	WeightPerUnit      float64   `json:"weightPerUnit"`      // 单果重量（克），如 220.0
}

// ============ 水果私有属性（仅 Buyer/Bank/Supplier 可见） ============
type FruitPrivate struct {
	ProductID     string  `json:"productID"`
	PricePerKg    float64 `json:"pricePerKg"`    // 元/公斤（面向买家/银行）
	CostPerKg     float64 `json:"costPerKg"`     // 成本价（供应商内部）
	SupplierBatch string  `json:"supplierBatch"` // 供应商批次号，如 "SUP-BATCH-20250401-A1"
	FarmID        string  `json:"farmID"`        // 农场编号，如 "FARM-SDYT-001"
}

// ============ 组合视图（查询用） ============
type FruitFull struct {
	Product      Product      `json:"product"`
	Fruit        FruitProduct `json:"Fruit"`
	FruitPrivate FruitPrivate `json:"privateDetails,omitempty"` // 可选字段
}

// 在 FruitProduct 上添加方法：从 FruitType 自动填充默认值
func (ffp *FruitProduct) ApplyDefaultSpec(fruitType FruitType) error {
	defaultSpec, err := GetDefaultFruitSpec(fruitType)
	if err != nil {
		return err
	}

	// 仅当未设置时才填充默认值（允许供应商覆盖）
	if ffp.ShelfLifeDays == 0 {
		ffp.ShelfLifeDays = defaultSpec.ShelfLifeDays
	}
	if ffp.OptimalTempMin == 0 && ffp.OptimalTempMax == 0 {
		ffp.OptimalTempMin = defaultSpec.OptimalTempMin
		ffp.OptimalTempMax = defaultSpec.OptimalTempMax
	}
	if ffp.OptimalHumidityMin == 0 && ffp.OptimalHumidityMax == 0 {
		ffp.OptimalHumidityMin = defaultSpec.OptimalHumidityMin
		ffp.OptimalHumidityMax = defaultSpec.OptimalHumidityMax
	}
	if ffp.SugarLevel == 0 {
		ffp.SugarLevel = defaultSpec.SugarLevelMin // 默认用最低糖度
	}

	return nil
}
