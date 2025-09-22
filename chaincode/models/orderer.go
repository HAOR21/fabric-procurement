package models

type PurchaseOrderStatus string

const (
	StatusCreated   PurchaseOrderStatus = "CREATED"
	StatusConfirmed PurchaseOrderStatus = "CONFIRMED"
	StatusShipped   PurchaseOrderStatus = "SHIPPED"
	StatusDelivered PurchaseOrderStatus = "DELIVERED"
	StatusCancelled PurchaseOrderStatus = "CANCELLED"
)

func (pos PurchaseOrderStatus) IsValid() bool {
	switch pos {
	case StatusCreated, StatusConfirmed, StatusShipped, StatusDelivered, StatusCancelled:
		return true
	default:
		return false
	}
}

// PurchaseOrder 采购订单
type PurchaseOrder struct {
	OrderID      string              `json:"orderID"`
	BuyerID      string              `json:"buyerID"`
	SupplierID   string              `json:"supplierID"` //确认后填充
	ProductID    string              `json:"productID"`
	QuantityKg   float64             `json:"quantityKg"`
	DeliveryDate string              `json:"deliveryDate"`
	Status       PurchaseOrderStatus `json:"status"`
	CreatedAt    string              `json:"createdAt"`
	ConfirmedAt  string              `json:"confirmedAt,omitempty"`
	ShippedAt    string              `json:"shippedAt,omitempty"`
	DeliveredAt  string              `json:"deliveredAt,omitempty"`
}
type PurchaseOrderPrivate struct {
	OrderID     string  `json:"orderID"`
	UnitPrice   float64 `json:"unitPrice"`   // 元/公斤 → 私有
	TotalAmount float64 `json:"totalAmount"` // QuantityKg * UnitPrice → 私有
	Currency    string  `json:"currency"`    // "CNY"
}

// OrderHistoryRecord 订单历史记录
type OrderHistoryRecord struct {
	TxID      string        `json:"txId"`
	Timestamp string        `json:"timestamp"`
	IsDeleted bool          `json:"isDeleted"`
	Order     PurchaseOrder `json:"order"`
}
