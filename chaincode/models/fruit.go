package models

import "fmt"

// FruitType 水果种类（枚举）
type FruitType string

// 所有支持的水果类型
const (
	FruitApple      FruitType = "APPLE"      // 苹果
	FruitOrange     FruitType = "ORANGE"     // 橙子
	FruitBanana     FruitType = "BANANA"     // 香蕉
	FruitGrape      FruitType = "GRAPE"      // 葡萄
	FruitStrawberry FruitType = "STRAWBERRY" // 草莓
	FruitMango      FruitType = "MANGO"      // 芒果
	FruitPeach      FruitType = "PEACH"      // 桃子
	FruitCherry     FruitType = "CHERRY"     // 樱桃
	FruitPineapple  FruitType = "PINEAPPLE"  // 菠萝
	FruitWatermelon FruitType = "WATERMELON" // 西瓜
)

// IsValid 检查水果类型是否合法
func (ft FruitType) IsValid() bool {
	switch ft {
	case FruitApple, FruitOrange, FruitBanana, FruitGrape, FruitStrawberry,
		FruitMango, FruitPeach, FruitCherry, FruitPineapple, FruitWatermelon:
		return true
	default:
		return false
	}
}

// String 实现 Stringer 接口
func (ft FruitType) String() string {
	return string(ft)
}

// AllFruitTypes 返回所有水果类型
func AllFruitTypes() []FruitType {
	return []FruitType{
		FruitApple, FruitOrange, FruitBanana, FruitGrape, FruitStrawberry,
		FruitMango, FruitPeach, FruitCherry, FruitPineapple, FruitWatermelon,
	}
}

// FruitSpec 水果默认特性模板（链码内置）
type FruitSpec struct {
	FruitType          FruitType `json:"fruitType"`
	OptimalTempMin     float64   `json:"optimalTempMin"`     // 最佳存储温度下限 (°C)
	OptimalTempMax     float64   `json:"optimalTempMax"`     // 最佳存储温度上限 (°C)
	OptimalHumidityMin float64   `json:"optimalHumidityMin"` // 最佳湿度下限 (%)
	OptimalHumidityMax float64   `json:"optimalHumidityMax"` // 最佳湿度上限 (%)
	ShelfLifeDays      int       `json:"shelfLifeDays"`      // 默认保质期（天）
	SugarLevelMin      float64   `json:"sugarLevelMin"`      // 最低糖度要求 (Brix)
	SugarLevelMax      float64   `json:"sugarLevelMax"`      // 最高糖度（可选，用于分级）
}

// GetDefaultFruitSpec 根据水果类型返回默认特性
func GetDefaultFruitSpec(fruitType FruitType) (*FruitSpec, error) {
	specs := map[FruitType]FruitSpec{
		FruitApple: {
			FruitType:          FruitApple,
			OptimalTempMin:     2.0,
			OptimalTempMax:     6.0,
			OptimalHumidityMin: 85.0,
			OptimalHumidityMax: 90.0,
			ShelfLifeDays:      30,
			SugarLevelMin:      12.0,
			SugarLevelMax:      18.0,
		},
		FruitOrange: {
			FruitType:          FruitOrange,
			OptimalTempMin:     4.0,
			OptimalTempMax:     8.0,
			OptimalHumidityMin: 85.0,
			OptimalHumidityMax: 90.0,
			ShelfLifeDays:      25,
			SugarLevelMin:      10.0,
			SugarLevelMax:      16.0,
		},
		FruitBanana: {
			FruitType:          FruitBanana,
			OptimalTempMin:     12.0, // 香蕉怕冷！
			OptimalTempMax:     16.0,
			OptimalHumidityMin: 85.0,
			OptimalHumidityMax: 95.0,
			ShelfLifeDays:      10,
			SugarLevelMin:      18.0, // 香蕉很甜
			SugarLevelMax:      24.0,
		},
		FruitStrawberry: {
			FruitType:          FruitStrawberry,
			OptimalTempMin:     0.0,
			OptimalTempMax:     2.0, // 草莓要冷！
			OptimalHumidityMin: 90.0,
			OptimalHumidityMax: 95.0,
			ShelfLifeDays:      5, // 易坏！
			SugarLevelMin:      7.0,
			SugarLevelMax:      12.0,
		},
		// 可继续添加其他水果...
	}

	if spec, exists := specs[fruitType]; exists {
		return &spec, nil
	}
	return nil, fmt.Errorf("no default spec for fruit type: %s", fruitType)
}
