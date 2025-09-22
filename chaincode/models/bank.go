package models

// LetterOfCreditStatus 信用证状态
type LetterOfCreditStatus string

const (
	LCStatusIssued    LetterOfCreditStatus = "ISSUED"
	LCStatusActivated LetterOfCreditStatus = "ACTIVATED"
	LCStatusPaid      LetterOfCreditStatus = "PAID"
	LCStatusExpired   LetterOfCreditStatus = "EXPIRED"
	LCStatusCancelled LetterOfCreditStatus = "CANCELLED"
)

// LetterOfCredit 信用证（私有数据，仅 Buyer/Bank/Supplier 可见）
type LetterOfCredit struct {
	LCID              string               `json:"lcID"`
	BuyerID           string               `json:"buyerID"`
	SupplierID        string               `json:"supplierID"`
	OrderID           string               `json:"orderID"`
	ProductID         string               `json:"productID"`
	Amount            float64              `json:"amount"`   // 总金额
	Currency          string               `json:"currency"` // "CNY"
	ExpiryDate        string               `json:"expiryDate"`
	Status            LetterOfCreditStatus `json:"status"`
	IssuedAt          string               `json:"issuedAt"`
	ActivatedAt       string               `json:"activatedAt,omitempty"`
	PaidAt            string               `json:"paidAt,omitempty"`
	PaymentConditions string               `json:"paymentConditions"` // "凭仓库收货单支付"
}

// PaymentRecord 放款记录（可选，用于审计）
type PaymentRecord struct {
	PaymentID  string  `json:"paymentID"`
	LCID       string  `json:"lcID"`
	Amount     float64 `json:"amount"`
	PaidAt     string  `json:"paidAt"`
	PaidByBank string  `json:"paidByBank"`
	ReceiptID  string  `json:"receiptID"` // 触发放款的收货单
}
