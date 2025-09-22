package contracts

import (
	"SupplyChain/config"
	"SupplyChain/models"
	. "SupplyChain/util"
	"fmt"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type BankContract struct {
	contractapi.Contract
}

// CreateLetterOfCredit 银行创建信用证
func (s *BankContract) CreateLetterOfCredit(
	ctx contractapi.TransactionContextInterface,
	lcID string,
	buyerID string,
	supplierID string,
	productID string,
	amount float64,
	expiryDate string,
) error {
	if err := IsCallerFromOrgType(ctx, "Bank"); err != nil {
		return err
	}

	// 检查信用证是否已存在
	if existing, _ := ctx.GetStub().GetState("LC_" + lcID); existing != nil {
		return fmt.Errorf("LC %s already exists", lcID)
	}

	lc := models.LetterOfCredit{
		LCID:              lcID,
		BuyerID:           buyerID,
		SupplierID:        supplierID,
		OrderID:           "",
		ProductID:         productID,
		Amount:            amount,
		Currency:          "CNY",
		ExpiryDate:        expiryDate,
		Status:            models.LCStatusIssued,
		IssuedAt:          NowUTC(),
		PaymentConditions: "凭仓库收货单支付",
	}

	bytes, err := Serialize(lc)
	if err != nil {
		return err
	}
	if err := ctx.GetStub().PutPrivateData(config.CollectionBuyerBankSupplier, "LC_"+lcID, bytes); err != nil {
		return fmt.Errorf("failed to put LC: %v", err)
	}
	return nil
}

// ApprovePayment 银行根据仓库收货放款
func (s *BankContract) ApprovePayment(ctx contractapi.TransactionContextInterface, lcID string, receiptID string) error {
	if err := IsCallerFromOrgType(ctx, "Bank"); err != nil {
		return err
	}

	// 检查仓库收货记录
	receiptBytes, err := ctx.GetStub().GetState("RECEIPT_" + receiptID)
	if err != nil || receiptBytes == nil {
		return fmt.Errorf("receipt %s not found", receiptID)
	}
	var receipt models.WarehouseReceipt
	if err := Deserialize(receiptBytes, &receipt); err != nil {
		return err
	}
	if receipt.InspectionResult != models.InspectionPassed || !receipt.TemperatureCompliance || !receipt.ShelfLifeCompliance {
		return fmt.Errorf("receipt %s not eligible for payment", receiptID)
	}

	// 读取并更新信用证
	lcBytes, err := ctx.GetStub().GetPrivateData(config.CollectionBuyerBankSupplier, "LC_"+lcID)
	if err != nil || lcBytes == nil {
		return fmt.Errorf("LC %s not found", lcID)
	}
	var lc models.LetterOfCredit
	if err := Deserialize(lcBytes, &lc); err != nil {
		return err
	}
	if lc.Status != models.LCStatusIssued && lc.Status != models.LCStatusActivated {
		return fmt.Errorf("LC %s status %s not payable", lcID, lc.Status)
	}
	lc.Status = models.LCStatusPaid
	lc.PaidAt = NowUTC()

	lcBytes, err = Serialize(lc)
	if err != nil {
		return err
	}
	if err := ctx.GetStub().PutPrivateData(config.CollectionBuyerBankSupplier, "LC_"+lcID, lcBytes); err != nil {
		return fmt.Errorf("failed to update LC: %v", err)
	}
	return nil
}

// GetFruitPrivate 银行查看水果私有价格（用于信用证审核）
func (s *BankContract) GetFruitPrivate(ctx contractapi.TransactionContextInterface, productID string) (*models.FruitPrivate, error) {
	if err := IsCallerFromOrgType(ctx, "Bank"); err != nil {
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
