# malatang

## Current Gameplay Notes

- `scenes/gameplay/main.tscn` is shared by the tutorial and Stage 1. The top street uses `StreetSpawnLeft/Right` and `StreetExitLeft/Right` for both customers and passerby NPCs; `street_total_spawn_count`, `street_customer_ratio`, and `street_same_side_exit_ratio` stay configurable on `GameManager`.
- Customers move from the street into cart-front wait spots, think for a short random time, then auto-create a pending order. They do not enter the player operation area.
- The cart table keeps the cooker in the middle, two staple ladles inside the cooker boundary, raw staple baskets behind the cart, a `DisposablePlateStack` beside `NoodleBasket`, and `TrashBin` at the right packing side.
- Raw glass noodles and raw noodles can be picked up directly. A disposable plate is required only before taking cooked staple food out of a ladle; taking cooked staple consumes the plate.
- `F` is the global service key: holding cooked staple hands it to the first matching pending customer anywhere; otherwise it announces ready cooked toppings so waiting customers can take them in order.
- After receiving a complete order, a customer eats, shows an evaluation, walks to `TrashDropSpot`, throws trash away, and exits without blocking day cleanup.
- The tutorial no longer teaches emergency restock. Tutorial Day 1 supplier noodle orders are available, and shortage handling on this map is driven through storage-side order adjustment or customer departure.



## 本轮更新



- 文本字典：`data/text_db.json` 是唯一展示文本来源；`data/card_db.json` 只保留卡牌池、文本 key 和 modifier 配置。

- 结算：最终日会先显示日结页，确认后进入完整轮结页；轮结页展示文案已迁入 `data/text_db.json`，轮结 summary 会在切换前写入缓存。

- 维护：新增 `tools/run_static_checks.ps1`、`tools/run_godot_checks.ps1` 和 `tools/smoke_test.gd`，用于静态检查、Godot headless 解析和最小经营流程 smoke 检查。

- 校验：`CookingSystem`、`OrderSystem`、`PendingOrderSystem` 的 `debug_validate()` 已补充大锅容量、漏勺/炉位、等待订单剩余内容和配送完成条件等业务一致性检查。

- 操作：玩家可以用方向键或 WASD 移动；大锅面板打开时，Esc 等同于点击“盖上锅盖”。

- 大锅：锅内支持多个独立批次。只要剩余容量足够，已有批次在煮时仍可以继续加入食材并启动新批次。





`malatang` 是一个 Godot 4.6 麻辣烫经营原型。玩家从标题页进入主页与选关页，在经营场景里移动到不同站点完成开店、点单、备餐、配送、补货、打烊和结算。



当前项目仍处在原型和重构并行阶段：`scenes/gameplay/game_manager.gd` 现在主要负责启动、节点引用、每帧调度、结算场景切换和少量外部兼容入口；真实玩法逻辑继续集中到 `gameplay/systems/` 与 `gameplay/models/`。



## 当前拆分状态



`scenes/gameplay/game_manager.gd` 现在主要作为启动/调度 facade 使用。站点交互、HUD 刷新、经济数据、夜间队列和 run 配置/日事件已经有独立入口，新增玩法逻辑不要继续堆回 `GameManager`：



- `InventorySystem`：库存初始化、库存文本、履约判断、缺货计算、库存扣减/增加和统一 `add_stock()`。

- `SupplierSystem`：普通补货面板、下单、倒计时、送达和待送达数量查询。

- `EmergencyPurchaseSystem`：等待订单缺货聚合、应急采购成本、扣钱补货和采购后顾客状态刷新。

- `CookingSystem`：大锅状态、配菜批量烹饪、主食漏勺、订单绑定炉位、手持主食、等待订单配菜提交和日终烹饪清理。

- `OrderSystem`：点单展示、订单评估、收银确认、付款后路由、配送点交互、完成配送、订单卡数据和状态文本。

- `PendingOrderSystem`：等待订单列表、增删、查询、首个可配送/待烹饪顾客和等待订单 debug 校验。

- `ReputationSystem`：顾客成功/失败统计、特殊顾客结果记录、声望 delta 和声望字段写入。

- `BusinessDaySystem`、`CustomerQueueSystem`、`SettlementBuilder`：营业日流程、队列/生成、结算摘要构建。

- `DayEventSystem`：白天礼物、每日营业事件、晨间提示和早晨生食奖励。

- `StationLayoutSystem`：经营场景站点按 `RunSetupData.station_layout` 放置。

- `EconomySystem`：资金、今日/本轮收入支出、利润摘要和运行时资金缓存同步。

- `GameplayHudSystem`：HUD 刷新、库存展示、金钱/声望显示和等待订单卡片刷新。

- `StationInteractionSystem`：柜台、锅、出餐口、仓库、应急采购、礼物盒、主食篮和漏勺的站点交互分发与提示文本。

- `NightQueueBuilder`：根据当天特殊顾客结果生成夜间结算队列。

- `CustomerOrderState`：集中封装顾客订单、库存预留、付款、离开、队列快照和特殊顾客状态访问；现在优先调用 `customer.gd` 明确方法，动态字段只作兼容 fallback。

- `RunEchoState`：承接特殊顾客礼物、打开记录和每日小摊回响统计；`RunSetupData` 保留原字段和方法作为 facade。

- `RunSettlementState`：承接最近一次日结/轮结 summary 和结算页模式；`RunSetupData` 保留原字段与 getter/setter 作为 facade。

- `RunRuntimeState`：承接 run 资金、累计收入/支出和当前库存缓存；`RunSetupData` 保留原字段与 getter/setter 作为 facade。

- `RunConfigState`：承接关卡天数、默认站点布局、基础食材/主食、供应商价格、包规格、应急倍率和起始资金。

- `RunDayEventState`：承接每日特殊顾客计划、夜间活动、明日事件、晨间信息和当日 modifier 查询。

- `CartPotPanelController`、`SupplierOrderPanelController`、`DayGiftPanelController`、`MorningInfoPanelController`：脚本化 UI controller，负责大锅、补货、礼物和晨间提示面板节点构建和刷新；晨间提示、礼物面板和补货面板已有 `.tscn` 场景化样板。

- `SettlementWidgetsController`：结算页猫粮/剩菜 widget 的脚本化构建入口，结算主页面继续负责流程和布局。



下一步重点不是继续把新玩法塞进 `GameManager`，而是把更多脚本化 UI controller 沉淀成独立 Control 场景，并把关卡、顾客和事件配置进一步数据化。



## 已实现功能



- 菜单流程：标题页、主页、选关页、进入经营场景。

- 玩家移动与站点交互：柜台、仓库、锅、配送点、应急采购、主食篮、礼物盒。

- 营业流程：开店、打烊、自动结束营业、收摊清理阶段、进入日结。

- 顾客流程：顾客生成、排队、耐心流失、离开、特殊顾客标记。

- 订单流程：查看订单、收银、即时交付、等待烹饪/配送。

- 库存系统：熟食库存、生食库存、主食库存，以及统一的库存文本、缺货判断和补货落库。

- 烹饪系统：大锅批量煮配菜、主食漏勺、等待订单交付。

- 补货系统：普通供应商补货、应急采购。

- 经济与声望：资金、今日收入、轮次收入、支出、声望变化。

- 结算系统：日结、最终日确认后进入轮结、剩余库存展示、进入下一天或返回主页。

- 夜间系统：特殊顾客回响、卡牌选择、当前效果记录。

- 结算互动：剩菜喂猫、摸猫反应。

- 全局菜单：经营场景中按 Tab 查看当前效果与未打开回响。



## 目录说明



- `project.godot`: Godot 项目配置。主场景是 `res://scenes/menus/title_menu.tscn`，autoload 也在这里注册。

- `autoload/`: 全局单例脚本。

  - `progress_data.gd`: 长期进度，例如二号锅、订单面板等级。

  - `run_setup_data.gd`: 当前 run 状态 facade，例如关卡、天数、资金、库存、特殊顾客、回响、结算缓存、配置和每日事件入口。

  - `text_db.gd`: 读取 `data/text_db.json`，提供 UI 文案和物品名。

  - `effect_manager.gd`: 读取 `data/card_db.json`，提供卡牌效果和 modifier 计算。

  - `global_run_menu.gd`: 经营场景中的 Tab 全局菜单。

- `data/`: 数据文件。

  - `text_db.json`: 中英文 UI 文案。

  - `card_db.json`: 夜间卡牌池、文本 key 和 modifier 配置；展示文本必须通过 `text_db.json`。

- `scenes/menus/`: 标题页、主页、选关页。

- `scenes/gameplay/`: 主经营场景、玩家、顾客、`GameManager`。

- `scenes/stations/`: 站点交互分发脚本。

- `scenes/ui/`: HUD、待处理订单卡，当前脚本化的大锅、补货、礼物和晨间提示 controller，以及晨间提示、礼物面板、补货面板 `.tscn` 样板。

- `scenes/settlement/`: 日结/轮结页面、喂猫区域、可拖拽剩菜按钮和局部 widget controller。

- `gameplay/systems/`: 正在拆分出的玩法系统。`InventorySystem`、`SupplierSystem`、`EmergencyPurchaseSystem`、`CookingSystem`、`OrderSystem`、`PendingOrderSystem`、`ReputationSystem`、`DayEventSystem`、`StationLayoutSystem`、`EconomySystem`、`GameplayHudSystem`、`StationInteractionSystem` 和 `NightQueueBuilder` 已经承接主要真实逻辑；`GameManager` 只保留必要兼容入口。

- `gameplay/models/`: 玩法常量和工具，例如物品 id、订单结果常量、库存工具、顾客订单状态访问 helper、run 回响状态 helper、run 结算状态 helper、run 运行时状态 helper、run 配置状态 helper 和 run 每日事件状态 helper。



## Debug 基础说明



Godot 运行入口应从 `project.godot` 的主场景进入：



```text

run/main_scene="res://scenes/menus/title_menu.tscn"

```



如果项目无法启动，优先检查：



- `project.godot` 的 autoload 路径是否仍指向 `res://autoload/...`。

- `.tscn` 里的脚本路径是否仍指向移动后的 `res://scenes/...`。

- `data/text_db.json` 和 `data/card_db.json` 是否能被读取。

- Godot 输出里是否有 missing resource、invalid get index、parse error。



运行时可以关注 `GameManager.debug_validate_runtime()` 的输出。它会检查关键节点、autoload、库存字典、队列数组和 system 状态，并通过 `push_warning` / `push_error` 给出提示。`InventorySystem`、`SupplierSystem`、`EmergencyPurchaseSystem`、`CookingSystem`、`OrderSystem`、`PendingOrderSystem` 已经提供 system 级 `debug_validate()`；其中烹饪、订单和等待订单系统会额外检查容量、炉位、漏勺、剩余订单内容和可配送状态等业务一致性。

本轮新增了可重复运行的维护检查：

```powershell
tools/run_static_checks.ps1
```

`run_static_checks.ps1` 会检查 Godot 不兼容的类型推断写法、空白错误、`data/text_db.json` 解析、结算页硬编码英文残留和 `TODO.md` 的完成记录残留。

```powershell
$env:GODOT_BIN="C:\Path\To\Godot.exe"
tools/run_godot_checks.ps1
```

`run_godot_checks.ps1` 会优先使用 `GODOT_BIN`，再探测常见 Windows 安装路径；找到 Godot 后运行 headless 项目解析，并执行 `res://tools/smoke_test.gd`。如果本机没有 Godot CLI，脚本会明确提示配置路径。



推荐手测路径：



1. 启动项目，进入标题页。

2. 开始游戏，进入主页，再进入选关页。

3. 选择关卡，进入经营场景。

4. 在柜台附近按 T 开店。

5. 等顾客排队后，在柜台按 E 查看订单，再按 E 收银。

6. 测试即时订单、需要大锅配菜的订单、需要主食漏勺的订单。

7. 在配送点交付订单。

8. 测试仓库普通补货和应急采购。

9. 打烊，等待清理条件满足，在柜台进入日结。

10. 测试夜间抽卡、剩菜喂猫、下一天或轮结返回主页。



如果本机没有 Godot CLI，可以做静态检查：



```powershell

git diff --check

rg "res://(game_manager|main|customer|player|title_menu|home_menu|stage_select|settlement_result|ui_layer|station_area|text_db|run_setup_data|progress_data|effect_manager|global_run_menu)"

```



第二条命令用于发现旧根目录资源路径残留。正常情况下，脚本和场景应指向 `res://scenes/...`、`res://autoload/...`、`res://gameplay/...`。



## 增删功能索引



### 菜单和关卡



- 新增关卡入口：改 `scenes/menus/stage_select.gd`。

- 设置关卡初始 run：改 `autoload/run_setup_data.gd` 的 `setup_stage_run()` 和默认布局逻辑。

- 做真正的关卡差异：建议在 `RunSetupData` 中增加按 stage id 分发的配置方法。



### 物品、库存和价格



- 新增食材或主食 id：改 `gameplay/models/item_ids.gd`。

- 新增物品显示名：改 `data/text_db.json`，必要时同步 `autoload/text_db.gd` 的映射。

- 修改初始库存：当前主要看 `scenes/gameplay/game_manager.gd` 中的 planned stock 字典，以及 `autoload/run_setup_data.gd` 的 run 库存；实际初始化由 `gameplay/systems/inventory_system.gd` 执行。

- 修改供应商基础价格、包裹数量、应急采购倍率：改 `autoload/run_setup_data.gd`。

- 修改库存文本、履约判断、缺货计算、熟食/生食扣减、零熟食模板、库存打印和通用补货落库：优先改 `gameplay/systems/inventory_system.gd`；`GameManager` 只保留必要库存字段镜像。



### 顾客和队列



- 修改顾客移动、耐心、订单内容、特殊顾客显示：改 `scenes/gameplay/customer.gd`。

- 修改订单/等待/付款/离开/特殊顾客状态访问：优先改 `scenes/gameplay/customer.gd` 的明确方法和 `gameplay/models/customer_order_state.gd` 的 facade。

- 修改顾客生成、队列位置、特殊顾客计划应用：改 `gameplay/systems/customer_queue_system.gd`。

- 修改每日特殊顾客计划：改 `autoload/run_setup_data.gd` 的 `setup_daily_special_customer_plan()`。



### 营业流程



- 修改营业时间、开店、打烊、收摊清理、进入日结条件：改 `gameplay/systems/business_day_system.gd`。

- `GameManager` 保留营业开关薄入口，外部站点仍可调用 `open_business()`、`close_business()` 等方法；清场和忙碌炉位判断由 `BusinessDaySystem` 持有。



### 订单、收银和配送



- 订单/配送真实流程已迁入 `gameplay/systems/order_system.gd`，`GameManager` 保留这些兼容入口：

  - `begin_checkout_for_customer()`

  - `confirm_checkout_and_create_order()`

  - `route_customer_after_payment()`

  - `interact_with_delivery_point()`

  - `complete_delivery_for_customer()`

- 等待订单列表由 `gameplay/systems/pending_order_system.gd` 持有，`GameManager.pending_customers` 仅作为兼容引用保留。

- 等待订单库存准备、主食预留、改单和拒单逻辑由 `OrderSystem` 承接；内部 system 应直接依赖 `OrderSystem`，不要绕回 `GameManager` 旧 wrapper。



### 烹饪



- 大锅状态、配菜烹饪、容量、主食漏勺、订单绑定炉位、手持主食、主食/配菜提交和日终烹饪清理已迁入 `gameplay/systems/cooking_system.gd`。

- 大锅面板构建和刷新由 `scenes/ui/cart_pot_panel_controller.gd` 承接；后续可继续拆成独立 `.tscn`。

- 与大锅相关的函数通常带有 `cart_pot`，与主食漏勺相关的函数通常带有 `staple_ladle`。



### 补货和应急采购



- 供应商订单、倒计时、送达和待送达数量查询主要在 `gameplay/systems/supplier_system.gd`；普通补货面板布局在 `scenes/ui/supplier_order_panel.tscn`，刷新和按钮绑定由 `scenes/ui/supplier_order_panel_controller.gd` 承接。

- 应急采购缺货聚合、采购成本、扣钱、补货和采购后刷新顾客状态主要在 `gameplay/systems/emergency_purchase_system.gd`。

- 两条补货路径的实际库存落库都统一调用 `InventorySystem.add_stock()`。



### 声望、回响和卡牌



- 声望变化、顾客成功/失败统计和特殊顾客结果记录主要在 `gameplay/systems/reputation_system.gd`。

- 白天礼物、每日营业事件、晨间提示和早晨生食奖励主要在 `gameplay/systems/day_event_system.gd`；`GameManager` 保留礼物/晨间提示兼容入口。

- 特殊顾客回响保存和每日统计：优先改 `gameplay/models/run_echo_state.gd`；`autoload/run_setup_data.gd` 保留 facade 方法。

- 最近一次日结/轮结 summary 和结算页模式：优先改 `gameplay/models/run_settlement_state.gd`；`autoload/run_setup_data.gd` 保留 `set_day_summary()`、`set_run_summary()`、`get_day_summary()`、`get_run_summary()`、`get_settlement_view_mode()` 作为 facade。

- Run 资金、累计收入/支出和当前库存缓存：优先改 `gameplay/models/run_runtime_state.gd`；`autoload/run_setup_data.gd` 保留原字段和 `set_money_state()`、`get_money_state()`、`set_stock_state()`、`get_stock_state()` 作为 facade。

- 卡牌数据：改 `data/card_db.json`。

- 卡牌读取和 modifier 计算：改 `autoload/effect_manager.gd`。



### UI 和结算



- HUD 金钱、库存、耐心、营业状态、待处理订单：改 `scenes/ui/ui_layer.gd`。

- 经营场景站点布局：改 `gameplay/systems/station_layout_system.gd` 和 `RunSetupData.station_layout`，不要把新布局规则塞回 `GameManager`。

- 晨间提示 UI：改 `scenes/ui/morning_info_panel.tscn` 和 `scenes/ui/morning_info_panel_controller.gd`。

- 礼物选择 UI：改 `scenes/ui/day_gift_panel.tscn` 和 `scenes/ui/day_gift_panel_controller.gd`。

- 待处理订单卡片：改 `scenes/ui/pending_order_card.gd` 和 `pending_order_card.tscn`。

- 日结/轮结页面、夜间抽卡、喂猫流程：改 `scenes/settlement/settlement_result.gd`；轮结正式文案写入 `data/text_db.json`，猫粮/剩菜 widget 构建优先改 `scenes/settlement/settlement_widgets_controller.gd`。

- 日结/轮结 summary 构建：改 `gameplay/systems/settlement_builder.gd`；收入资金来自 `EconomySystem`，库存文本来自 `InventorySystem`，最终仍以明确 input dictionary 构建 summary。



### 文案



- 所有正式展示文案都改 `data/text_db.json`，包括 UI、物品名、状态名和卡牌名/描述。

- 如果新增物品或状态，需要同步 `autoload/text_db.gd` 中的 `item_key_map` 或 `status_key_map`。

- 代码里仍有部分硬编码中文，后续应逐步迁入 `text_db.json`。
