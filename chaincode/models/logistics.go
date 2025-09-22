package models

// LogisticsStatus 运输状态
type LogisticsStatus string

const (
	logisticsStatusPending          LogisticsStatus = "PENDING"
	logisticsStatusInTransit        LogisticsStatus = "IN_TRANSIT"
	logisticsStatusTemperatureAlert LogisticsStatus = "TEMPERATURE_ALERT"
	logisticsStatusDelivered        LogisticsStatus = "DELIVERED"
	logisticsStatusException        LogisticsStatus = "EXCEPTION"
)

// Logistics 运输单（公开）
type Logistics struct {
	LogisticsID     string          `json:"logisticsID"`
	OrderID         string          `json:"orderID"`
	ProductID       string          `json:"productID"`
	From            string          `json:"from"` // 起运地
	To              string          `json:"to"`   // 目的地
	Status          LogisticsStatus `json:"status"`
	CurrentLocation string          `json:"currentLocation,omitempty"`
	ETADate         string          `json:"etaDate,omitempty"`
	CreatedAt       string          `json:"createdAt"`
	UpdatedAt       string          `json:"updatedAt,omitempty"`
}

// LogisticsPrivate 私有温控数据（仅 Buyer/Warehouse/Logistics 可见）
type LogisticsPrivate struct {
	LogisticsID    string           `json:"logisticsID"`
	TemperatureLog []TemperatureLog `json:"temperatureLog"` // 温控日志
	HumidityLog    []HumidityLog    `json:"humidityLog"`    // 湿度日志（可选）
	GPSLog         []GPSLog         `json:"gpsLog"`         // GPS轨迹（可选）
}

type TemperatureLog struct {
	Timestamp   string  `json:"timestamp"`
	Temperature float64 `json:"temperature"`
	MinAllowed  float64 `json:"minAllowed"` // 来自 FruitProduct
	MaxAllowed  float64 `json:"maxAllowed"`
	IsAlert     bool    `json:"isAlert"` // 是否超温
}

type HumidityLog struct {
	Timestamp  string  `json:"timestamp"`
	Humidity   float64 `json:"humidity"`
	MinAllowed float64 `json:"minAllowed"`
	MaxAllowed float64 `json:"maxAllowed"`
	IsAlert    bool    `json:"isAlert"`
}

type GPSLog struct {
	Timestamp string  `json:"timestamp"`
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}
