package config

// 私有数据集合名称 —— 必须与 collections_config.json 中定义一致
const (
	CollectionBuyerBankSupplier       = "collectionBuyerBankSupplier"       // 商品价格、信用证金额
	CollectionBuyerWarehouseLogistics = "collectionBuyerWarehouseLogistics" // 物流GPS、温控、质检报告
	CollectionBankOnly                = "collectionBankOnly"                // 银行内部风控数据
)
