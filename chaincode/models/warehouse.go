package models

// InspectionResult 质检结果
type InspectionResult string

const (
	InspectionPassed  InspectionResult = "PASSED"
	InspectionFailed  InspectionResult = "FAILED"
	InspectionPending InspectionResult = "PENDING"
)

// WarehouseReceipt 仓库收货单
type WarehouseReceipt struct {
	ReceiptID             string           `json:"receiptID"`
	LogisticsID           string           `json:"logisticsID"`
	OrderID               string           `json:"orderID"`
	ProductID             string           `json:"productID"`
	ReceivedKg            float64          `json:"receivedKg"`       // 实收重量
	InspectionResult      InspectionResult `json:"inspectionResult"` //质检结果
	QualityRemarks        string           `json:"qualityRemarks,omitempty"`
	ReceivedAt            string           `json:"receivedAt"`
	ReceivedBy            string           `json:"receivedBy"`            // 仓库MSPID
	TemperatureCompliance bool             `json:"temperatureCompliance"` // 是否全程温控合规
	ShelfLifeCompliance   bool             `json:"shelfLifeCompliance"`   // 是否在保质期内
}

// ReceiptHistoryRecord 收货历史
type ReceiptHistoryRecord struct {
	TxID      string           `json:"txId"`
	Timestamp string           `json:"timestamp"`
	IsDeleted bool             `json:"isDeleted"`
	Receipt   WarehouseReceipt `json:"receipt"`
}
