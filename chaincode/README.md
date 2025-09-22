## 供应链溯源与融资链码（Hyperledger Fabric / Go）

### 概览
一个面向“生鲜水果供应链”的 Fabric 链码，覆盖 从商品建模 → 买家下单 → 供应商确认 → 物流运输（温控/GPS 私有数据）→ 仓库签收与质检 → 银行信用证与放款 的端到端业务流程。项目完整体现了：
- 数据模型的公开/私有拆分与组合查询
- 多参与方合约的权限边界与最小授权
- 私有数据集合（PDC）与 CouchDB 世界状态实践
- 可审计的历史查询与状态机式订单流转

### 目录结构
```
SupplyChain/
├─ README.md
│  - 面向面试展示：业务流、PDC、键前缀、部署与调用要点
├─ go.mod / go.sum
│  - 使用 fabric-contract-api-go（多合约入口），兼容 CouchDB 世界状态
├─ config/
│  ├─ collections.go
│  │  - 定义 PDC 名称常量：
│  │    - collectionBuyerBankSupplier：价格、订单私有、信用证
│  │    - collectionBuyerWarehouseLogistics：温控/GPS/湿度日志
│  │    - collectionBankOnly：银行风控（可选）
│  └─ collections_config.json
│     - PDC 配置文件（部署时通过 --collections-config 传入，链码不直接读取）
│     - 各集合：策略、memberOnlyRead/Write、blockToLive 等
├─ util/
│  └─ utils.go
│     - 权限校验：IsCallerFromOrgType/IsCallerFromAnyOrg（基于 MSPID 前缀）
│     - 序列化/反序列化：Serialize/Deserialize（链码内统一 JSON 编解码）
│     - NowUTC：统一 RFC3339 时间戳
│     - CreateCompositeKey：一对多建索引能力（可扩展富查询场景）
├─ models/
│  ├─ product.go
│  │  - Product（通用公开）：Type 标注资源类型（如 FRUIT），标准键=productID
│  │  - FruitProduct（公开专属）：温控阈值、采摘等；与 ProductID 关联
│  │  - FruitPrivate（PDC）：价格、成本、批次、农场（敏感）
│  │  - FruitFull（组合视图）：聚合公开+私有，便于一次性查询
│  ├─ fruit.go
│  │  - FruitType（枚举）+ FruitSpec（默认规格模板）
│  │  - GetDefaultFruitSpec：按类型提供默认阈值（温度/湿度/保质/糖度）
│  │  - ApplyDefaultSpec：仅对空值进行默认填充（支持供应商覆盖）
│  ├─ orderer.go
│  │  - PurchaseOrder（公开）/ PurchaseOrderPrivate（PDC）
│  │  - 状态机：CREATED → CONFIRMED → SHIPPED → DELIVERED/…
│  │  - OrderHistoryRecord：可审计变更轨迹（GetHistoryForKey）
│  ├─ logistics.go
│  │  - Logistics（公开）：状态、当前位置、ETA、时间戳
│  │  - LogisticsPrivate（PDC）：TemperatureLog/HumidityLog/GPSLog
│  │  - 温控日志包含阈值快照与 IsAlert（留痕审计）
│  ├─ warehouse.go
│  │  - WarehouseReceipt：收货、质检结果、温控/保质合规位
│  │  - ReceiptHistoryRecord：用于审计（历史接口可扩展）
│  └─ bank.go
│     - LetterOfCredit（信用证，建议放 Buyer/Bank/Supplier 可见集合）
│     - PaymentRecord：放款审计（可选）
├─ contracts/
│  ├─ buyer_contract.go
│  │  - CreatePurchaseOrder：从 PDC 读取价格，写订单公开与私有（订单私有金额=数量×单价）
│  │  - GetOrder / GetOrderHistory：迁移自 OrderContract，Buyer/Supplier 可读
│  │  - GetFruitProduct / GetFruitPrivate：商品公开与私有查询
│  │  - 风险控制：参数校验、重复键检查、商品存在性检查
│  ├─ supplier_contract.go
│  │  - CreateFruitProduct：创建 Product（Type=FRUIT）与 FruitProduct（公开）+ FruitPrivate（PDC）
│  │  - ConfirmOrder：仅对 CREATED 订单确认；回填 SupplierID/时间戳
│  │  - 采用 ApplyDefaultSpec 对未设置阈值的字段进行默认化
│  ├─ logistics_contract.go
│  │  - CreateLogistics：校验订单已 CONFIRMED，回填 ProductID；写 LOGISTICS_<id>
│  │  - UpdateLogisticsStatus：状态枚举校验；更新位置/时间；追加温度日志至 PDC
│  │  - 温控日志追加：读取 FruitProduct 阈值，计算 IsAlert 并持久化
│  ├─ warehouse_contract.go
│  │  - ReceiveLogistics：读取 LOGISTICS 与 FRUIT；判定温控/保质（HarvestDate+ShelfLifeDays）合规
│  │  - 生成 RECEIPT_<id>；可扩展写入收货重量/签收组织等
│  └─ bank_contract.go
│     - CreateLetterOfCredit：在 PDC 写入 LC，本体对 Buyer/Bank/Supplier 可见
│     - ApprovePayment：读取 RECEIPT 校验合规后置 LC 为 PAID
│     - 可扩展：风控细则至 collectionBankOnly
```



- `models/`：领域模型（公开与私有）。
  - `product.go`：通用 `Product`；水果专属 `FruitProduct` 与私有 `FruitPrivate`；组合视图 `FruitFull`。
  - `fruit.go`：`FruitType` 枚举与默认规格 `FruitSpec`；`ApplyDefaultSpec` 用于自动填充。
  - `orderer.go`：`PurchaseOrder`（公开）与 `PurchaseOrderPrivate`（私有），订单历史 `OrderHistoryRecord`。
  - `logistics.go`：公开 `Logistics` 与私有 `LogisticsPrivate`（温度/湿度/GPS 日志）。
  - `warehouse.go`：`WarehouseReceipt` 收货与质检。
  - `bank.go`：`LetterOfCredit` 信用证与 `PaymentRecord` 放款记录。
- `contracts/`：业务合约（按角色拆分）。
  - `supplier_contract.go`：创建水果商品（公开+私有）；确认订单。
  - `buyer_contract.go`：创建采购订单（公开+私有价格）；订单读取与历史审计；查看水果信息/私有价。
  - `logistics_contract.go`：创建物流（校验订单已确认并回填 `ProductID`）；更新物流状态；写入温度日志（私有集合）。
  - `warehouse_contract.go`：签收物流，判断温控与保质期合规，生成 `RECEIPT_*`。
  - `bank_contract.go`：创建信用证（PDC）；基于收货单放款并更新信用证状态。
- `config/`
  - `collections.go`：PDC 名称常量。
  - `collections_config.json`：私有数据集合定义（部署时通过参数传入 Peer）。
- `util/utils.go`：工具函数（权限校验、序列化、UTC 时间等）。

### 权限模型（基于 MSPID 前缀）
- `Buyer*MSP` 只能创建订单和查询自身所需信息。
- `Supplier*MSP` 只能创建商品、确认订单。
- `Logistics*MSP` 只能创建/更新物流。
- `Warehouse*MSP` 只能签收与质检。
- `Bank*MSP` 只能创建信用证并放款。

提示：代码使用 `IsCallerFromOrgType(ctx, "Buyer"|"Supplier"|...)` 通过 MSPID 前缀判断调用者所属角色。实际网络中请将 MSP 命名与之对齐（如 `Buyer1MSP`、`Supplier1MSP` 等），或替换为更严格的属性/身份校验。

### 私有数据集合（PDC）
- `collectionBuyerBankSupplier`：买家/银行/供应商共享的敏感商务数据
  - `FRUIT_PRIVATE_<productID>`：水果价格、成本、批次等
  - `ORDER_PRIVATE_<orderID>`：订单的成交价、总金额
  - `LC_<lcID>`：信用证本体（可选：银行风控细项放 `collectionBankOnly`）
- `collectionBuyerWarehouseLogistics`：买家/仓库/物流共享
  - `LOGISTICS_PRIVATE_<logisticsID>`：温度/湿度/GPS 日志
- `collectionBankOnly`：银行内部风控数据（可选）

说明：链码“不会主动读取 collections_config.json 文件”，但部署链码时必须在 Peer 提交/批准阶段通过 `--collections-config` 提供该文件，使集合策略在通道上生效。建议将该文件与代码一并版本管理。

### 世界状态键前缀
- 公开：
  - `productID`：通用商品
  - `FRUIT_<productID>`：水果专属公开属性
  - `<orderID>`：采购订单（公开）
  - `LOGISTICS_<logisticsID>`：物流单
  - `RECEIPT_<receiptID>`：仓库收货单
- 私有：
  - `FRUIT_PRIVATE_<productID>`、`ORDER_PRIVATE_<orderID>`、`LOGISTICS_PRIVATE_<logisticsID>`、`LC_<lcID>`

### 典型业务流
1) 供应商：`SupplierContract.CreateFruitProduct`
   - 写入 `Product`（公开，`Type=FRUIT`）与 `FruitProduct`（公开）、`FruitPrivate`（PDC）。
2) 买家：`BuyerContract.CreatePurchaseOrder`
   - 从 PDC 读取产品私有价格；写入订单公开头与订单私有明细。
3) 供应商：`SupplierContract.ConfirmOrder`
   - 校验并确认订单（回填 `SupplierID`）。
4) 物流：`LogisticsContract.CreateLogistics` / `UpdateLogisticsStatus`
   - 校验订单已确认并回填 `ProductID`；更新状态和位置；追加温度日志到 PDC。
5) 仓库：`WarehouseContract.ReceiveLogistics`
   - 依据水果的采摘日期 `+ ShelfLifeDays` 判断保质；依据 `OptimalTempMin/Max` 判断温控；生成收货单。
6) 银行：`BankContract.CreateLetterOfCredit` / `ApprovePayment`
   - 在 PDC 创建信用证；校验收货单合规后标记信用证 `PAID`。

### 部署与调用（示例）
以下以 fabric-samples `test-network`（启用 CouchDB）为例：
- 启动网络和通道：
  - `./network.sh up createChannel -c mychannel -s couchdb`
- 部署链码（Go，携带集合配置）：
  - `./network.sh deployCC -c mychannel -ccn supplychain -ccp <ABS_PATH_TO_THIS_REPO> -ccl go -cccg <ABS_PATH_TO_THIS_REPO>/config/collections_config.json`
  - 说明：Fabric v2+ 多合约模式通过链码入口注册（本仓库已在入口中注册各合约）。
- 调用方式（注意切换不同组织身份）示例：
  - 供应商建商品：
    - `peer chaincode invoke -C mychannel -n supplychain -c '{"function":"SupplierContract:CreateFruitProduct","Args":["P1","苹果","好苹果","SKU1","APPLE","山东","2025-04-01","0","0","0","0","0","0","[]","红富士","220","10.5","8.0","BATCH1","FARM1"]}'`
  - 买家下单：
    - `peer chaincode invoke -C mychannel -n supplychain -c '{"function":"BuyerContract:CreatePurchaseOrder","Args":["O1","P1","100","2025-10-01"]}'`
  - 供应商确认：
    - `peer chaincode invoke -C mychannel -n supplychain -c '{"function":"SupplierContract:ConfirmOrder","Args":["O1"]}'`
  - 物流创建/更新；仓库签收；银行信用证/放款依次调用。

提示：本项目使用 MSPID 前缀判断组织角色（如 `Buyer1MSP`），请确保网络 MSP 命名与之相符，或替换权限校验逻辑。

### CouchDB 与富查询
- 即使未使用富查询，Peer 配置为 CouchDB 时，世界状态与 PDC 仍落在 CouchDB。
- 使用富查询/分页时，建议添加索引文件到 `META-INF/statedb/couchdb/indexes/*.json`，并在链码中使用 `GetQueryResult` 等 API。


### 设计亮点与可扩展点
- 公开/私有模型拆分清晰；键前缀统一，易于审计与排障。
- PDC 权限边界明确：商业敏感数据（报价、信用证）与物流隐私数据（温控/GPS）分开管理。
- 物流温控日志实时阈值判定，可扩展湿度与 GPS 告警策略。
- 订单/收货/信用证全链条可追溯，具备历史审计接口。

### 许可证
本仓库用于学习与面试展示，按需自定义许可证。


