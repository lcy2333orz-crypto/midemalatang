# TODO

这个文件记录项目的维护风险、后续拆分方向和可扩展玩法入口。当前项目仍处于“原型功能可跑 + 架构逐步整理”的阶段，优先目标是保证现有流程稳定，再逐步把大文件拆干净。

## 高优先级代码隐患

- `scenes/gameplay/game_manager.gd` 仍然过大。营业日、顾客队列和结算摘要已经开始迁出，但订单、库存、烹饪、补货、应急采购、声望仍高度耦合。
- `gameplay/systems/` 中部分 system 还是 wrapper 或预留接口，尚未真正持有状态。迁移时要避免误以为所有逻辑都已经离开 `GameManager`。
- 顾客状态大量通过动态字段访问，例如 `customer.order_served`、`customer.needs_emergency_purchase`、`customer.get("...")`。后续应收紧成明确方法，减少运行时字段名错误。
- UI 构建逻辑混在玩法脚本中，尤其是大锅面板、补货面板、日结页面。后续可以拆成独立 Control 场景或 UI controller。
- 文案来源混杂。部分文本走 `data/text_db.json`，部分文本硬编码在脚本里。新增正式 UI 时优先写入 `text_db.json`。
- 当前缺少 Godot CLI 自动验证流程。本地命令行里如果没有 `godot`，只能做静态检查和手测。
- 迁移过程中要注意文件编码。脚本里已有中文文案，编辑工具需要保持 UTF-8。
- `RunSetupData` 同时承担配置、运行时状态、结算缓存和事件生成职责，后续可能继续拆分。

## 待继续拆分

推荐拆分顺序：

1. `InventorySystem`
   - 迁移库存初始化、库存文本、库存扣减、缺货计算。
   - 目标文件：`gameplay/systems/inventory_system.gd`。
   - 相关旧逻辑：`scenes/gameplay/game_manager.gd` 中 `initialize_round_stocks()`、`get_*_stock_text()`、`can_fulfill_*()`、`get_order_shortage()`、`deduct_cooked_stock()`。

2. `SupplierSystem` 与 `EmergencyPurchaseSystem`
   - 普通补货和应急采购都依赖库存，适合在库存拆分后处理。
   - 目标文件：`gameplay/systems/supplier_system.gd`、`gameplay/systems/emergency_purchase_system.gd`。
   - 相关旧逻辑：供应商订单面板、订单倒计时、送达、缺货聚合、应急采购扣钱和补库存。

3. `CookingSystem`
   - 迁移大锅、主食漏勺、烹饪计时、完成状态、向订单提交食物。
   - 目标文件：`gameplay/systems/cooking_system.gd`。
   - 可考虑把大锅 UI 后续拆成独立场景，例如 `scenes/ui/cart_pot_panel.tscn`。

4. `OrderSystem`
   - 迁移点单、收银、订单评估、订单路由、配送、订单卡数据。
   - 目标文件：`gameplay/systems/order_system.gd`。
   - 该系统依赖库存和烹饪，建议放在它们之后迁移。

5. `ReputationSystem`
   - 迁移顾客成功/失败统计、特殊顾客回响记录、声望变化。
   - 目标文件：`gameplay/systems/reputation_system.gd`。
   - 迁移后 `GameManager` 只保留兼容 wrapper。

6. `SettlementBuilder`
   - 已经迁出 summary 构建，但仍依赖 `manager` 读取数据。
   - 后续目标是输入明确的结算数据，而不是直接访问 `GameManager`。

## 后续玩法功能

- 关卡差异化
  - 当前 `stage_1` 和 `stage_2` 共享大量默认设置。
  - 推荐位置：`autoload/run_setup_data.gd`，必要时新增 `data/stage_db.json`。

- 顾客类型池
  - 支持普通顾客、特殊顾客、不同耐心/订单偏好/声望影响。
  - 推荐位置：`gameplay/systems/customer_queue_system.gd`、`scenes/gameplay/customer.gd`。

- 特殊顾客不再每天固定
  - 当前 `setup_daily_special_customer_plan()` 每天固定生成一个特殊顾客。
  - 推荐位置：`autoload/run_setup_data.gd`，后续可接关卡配置或随机池。

- 卡牌随机、权重和稀有度
  - 当前卡牌选择偏 deterministic，主要取固定池。
  - 推荐位置：`data/card_db.json`、`autoload/effect_manager.gd`、`scenes/settlement/settlement_result.gd`。

- 更多食材和主食
  - 推荐位置：`gameplay/models/item_ids.gd`、`data/text_db.json`、`autoload/run_setup_data.gd`。
  - 还需要检查库存、订单、烹饪和补货逻辑是否按 item id 通用处理。

- 升级系统
  - 目前已有二号锅和订单面板等级字段。
  - 推荐位置：`autoload/progress_data.gd`、`autoload/run_setup_data.gd`、`gameplay/systems/settlement_builder.gd`。

- 地图和手账功能
  - 当前主页按钮存在，但功能未实现。
  - 推荐位置：新增 `scenes/menus/notebook.tscn`、`scenes/menus/map.tscn`，并从 `home_menu.gd` 跳转。

- 设置页和开发名单
  - 当前标题页按钮存在，但只显示未制作提示。
  - 推荐位置：`scenes/menus/title_menu.gd`，新增对应场景。

- 存档系统
  - 目前 `ProgressData` 和 `RunSetupData` 是运行时状态，没有持久保存。
  - 推荐位置：新增 `autoload/save_data.gd`，保存 `ProgressData` 和必要 run 信息。

- 新手提示和站点反馈
  - 当前大量反馈依赖 `print()`。
  - 推荐位置：`scenes/ui/ui_layer.gd`，可新增提示 Label 或消息队列。

## 推荐功能落点

- 新增菜单页面：`scenes/menus/`。
- 新增经营场景对象：`scenes/gameplay/`。
- 新增站点交互：`scenes/stations/station_area.gd`，再转发到对应 system。
- 新增 HUD/面板：`scenes/ui/`。
- 新增结算互动：`scenes/settlement/`。
- 新增跨场景状态：`autoload/run_setup_data.gd` 或 `autoload/progress_data.gd`。
- 新增玩法规则：优先放 `gameplay/systems/`，不要继续堆进 `GameManager`。
- 新增常量/工具：`gameplay/models/`。
- 新增文本：`data/text_db.json`。
- 新增卡牌：`data/card_db.json`。

## Debug 待办

- 记录 Godot 可执行文件路径，并考虑添加本地脚本运行 Godot CLI 检查。
- 建立最小回归清单：启动、选关、开店、点单、收银、烹饪、配送、补货、应急采购、打烊、日结、下一天、轮结。
- 给 `InventorySystem`、`CookingSystem`、`OrderSystem` 增加更具体的 `debug_validate()`。
- 给关键 wrapper 增加必要的 debug guard，但不要在每帧打印噪音。
- 后续可添加简单 smoke test 场景或 debug command，自动跑一次基本营业流程。

## 已知设计问题

- 特殊顾客是否每天固定出现尚未确定。
- 第二关和第一关目前缺少明确差异。
- 夜间卡牌是否应洗牌、加权或按稀有度生成尚未确定。
- 熟食不过夜、主食/生食可继承的规则已经存在，但需要在 UI 中更清楚地表达。
- 是否需要失败条件、胜利条件、目标利润或声望目标尚未确定。
