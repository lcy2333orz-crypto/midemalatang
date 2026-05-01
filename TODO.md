# TODO

这个文件记录项目的维护风险、后续拆分方向和可扩展玩法入口。当前项目仍处于“原型功能可跑 + 架构逐步整理”的阶段，优先目标是保证现有流程稳定，再逐步把大文件拆干净。

## 高优先级代码隐患

- `scenes/gameplay/game_manager.gd` 仍然偏大，但已经从约 3361 行继续降到约 1700 行以内。营业日、顾客队列、等待订单、库存核心逻辑、供应商补货、应急采购、烹饪状态机、订单/配送、声望、结算摘要输入、订单库存准备、主食预留和主要脚本化 UI controller 已经开始迁出；剩余高风险耦合主要是旧 public wrapper、`RunSetupData` 配置/运行时职责深拆和更细的 UI 场景化。
- `gameplay/systems/` 中主要玩法 system 已承接真实逻辑。`InventorySystem`、`SupplierSystem`、`EmergencyPurchaseSystem`、`CookingSystem`、`OrderSystem`、`ReputationSystem` 都是当前优先维护入口；`GameManager` 负责兼容分发和跨 system 协调。
- 顾客订单状态已新增 `CustomerOrderState` helper 集中访问，并扩展到库存预留、付款、离开、队列快照和特殊顾客字段；`customer.gd` 已补明确 getter/setter，helper 优先调用方法，动态字段仅作兼容 fallback。
- UI 构建逻辑已先迁出大锅面板、补货面板、礼物面板、晨间提示和结算页猫粮/剩菜 widget；晨间提示已有 `.tscn` 样板，日结页面剩余流程 UI 和其他脚本化 controller 后续可以继续拆成独立 Control 场景。
- 文案来源混杂。部分文本走 `data/text_db.json`，部分文本硬编码在脚本里。新增正式 UI 时优先写入 `text_db.json`。
- 当前缺少 Godot CLI 自动验证流程。本地命令行里如果没有 `godot`，只能做静态检查和手测。
- 迁移过程中要注意文件编码。脚本里已有中文文案，编辑工具需要保持 UTF-8。
- `RunSetupData` 仍同时承担配置、运行时状态、结算缓存和事件生成职责；特殊顾客礼物/每日回响已先迁到 `RunEchoState`，后续继续拆配置、运行时资金/库存和结算缓存。

## 待继续拆分

推荐拆分顺序：

1. UI controller / panel scenes
   - 把日结页面剩余即时构建 UI 继续拆出去。
   - 可考虑把现有 `cart_pot_panel_controller.gd`、`supplier_order_panel_controller.gd`、`day_gift_panel_controller.gd` 继续固化为 `.tscn` 场景。

2. 顾客动态字段正式化
   - 继续减少 `CustomerOrderState` fallback 中的动态 `get/set`，最终把顾客脚本字段改成强约束方法访问。
   - 当前 helper 已覆盖订单等待、库存预留、付款/离开、队列快照和特殊顾客字段，并优先调用 `customer.gd` 明确方法。

3. `GameManager` wrapper 收口
   - 继续确认哪些旧 public wrapper 仍被 `station_area.gd`、UI 或顾客脚本调用。
   - 只删除确认为内部遗留且已有 system 直接依赖替代的 wrapper。

4. `RunSetupData` 职责拆分
   - 后续把关卡配置、运行时资金/库存、结算缓存和夜间事件生成拆成更明确的 model/service。
   - 拆分前保持现有 autoload 输出结构，避免破坏菜单、经营场景和结算页的数据入口。

## 已完成拆分

- `InventorySystem`
  - 已迁移库存初始化、库存文本、熟食/生食库存扣减与增加、通用补货、订单履约判断和缺货计算。
  - `GameManager` 仍保留 `initialize_round_stocks()`、`get_*_stock_text()`、`can_fulfill_*()`、`get_order_shortage()`、`deduct_cooked_stock()` 等兼容 wrapper。
  - 普通供应商送达、应急采购补货、礼物库存和早晨生食奖励已改为调用 `InventorySystem.add_stock()`。
  - `InventorySystem.debug_validate()` 已增加库存字典类型、非负整数和 `RunSetupData.current_*_stock` 同步检查。
- `SupplierSystem`
  - 已持有供应商订单队列和订单序号。
  - 已迁移普通补货下单、倒计时、送达、待送达数量查询。
  - 补货面板构建和刷新已迁到 `scenes/ui/supplier_order_panel_controller.gd`。
- `EmergencyPurchaseSystem`
  - 已迁移等待订单缺货聚合、单个顾客缺货判断、应急采购成本、扣钱后补货和采购后顾客状态刷新。
  - 实际库存写入继续统一调用 `InventorySystem.add_stock()`。
- `ReputationSystem`
  - 已迁移顾客成功/失败统计、特殊顾客回响记录、声望 delta 计算和声望字段更新。
- `CookingSystem`
  - 已迁移大锅状态、容量选择、批量烹饪、主食漏勺、手持主食、等待订单配菜提交、主食提交和日终烹饪清理。
  - 大锅面板构建和刷新已迁到 `scenes/ui/cart_pot_panel_controller.gd`。
  - `GameManager` 仍保留 `open_cart_pot_panel()`、`interact_with_staple_basket()`、`interact_with_staple_ladle()`、`try_fulfill_cart_ingredients_for_customer()` 等兼容 wrapper。
- `OrderSystem`
  - 已迁移点单展示、订单评估、收银确认、付款后路由、配送点交互、完成配送、订单卡数据和状态文本。
  - 已承接等待订单库存准备、主食预留、缺货改单和收银前拒单逻辑；`GameManager` 仅保留同名兼容 wrapper。
- `PendingOrderSystem`
  - 已持有等待订单列表，并提供增删、查询、首个可配送/待烹饪顾客和 debug 校验。
  - `GameManager.pending_customers` 仅作为兼容引用保留。
- `CustomerOrderState`
  - 已集中封装订单等待、库存预留、付款、离开、队列快照和特殊顾客相关状态，供 `OrderSystem`、`CookingSystem`、`EmergencyPurchaseSystem`、`ReputationSystem`、`CustomerQueueSystem` 等优先使用。
  - 已改为优先调用 `customer.gd` 明确 getter/setter，动态字段只作为兼容 fallback。
- `RunEchoState`
  - 已承接特殊顾客礼物、打开记录和每日小摊回响统计。
  - `RunSetupData` 保留原字段和 public 方法作为 facade，避免一次性改菜单、经营场景和结算调用面。
- `SettlementBuilder`
  - 已改为接收明确 summary input dictionary，不再读取 `GameManager` 的收入、资金和库存文本字段。
- UI controller
  - `CartPotPanelController`、`SupplierOrderPanelController`、`DayGiftPanelController`、`MorningInfoPanelController` 已承接对应脚本化面板构建。
  - `MorningInfoPanelController` 已开始使用 `morning_info_panel.tscn` 作为 UI 场景化样板。
  - `SettlementWidgetsController` 已承接结算页猫粮/剩菜 widget 构建。

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
- 继续给 `CookingSystem`、`OrderSystem`、`PendingOrderSystem` 增加更具体的业务一致性 `debug_validate()`，例如大锅容量、漏勺状态、等待订单剩余内容和配送完成条件。
- 给关键 wrapper 增加必要的 debug guard，但不要在每帧打印噪音。
- 后续可添加简单 smoke test 场景或 debug command，自动跑一次基本营业流程。

## 已知设计问题

- 特殊顾客是否每天固定出现尚未确定。
- 第二关和第一关目前缺少明确差异。
- 夜间卡牌是否应洗牌、加权或按稀有度生成尚未确定。
- 熟食不过夜、主食/生食可继承的规则已经存在，但需要在 UI 中更清楚地表达。
- 是否需要失败条件、胜利条件、目标利润或声望目标尚未确定。
