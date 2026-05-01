# malatang

`malatang` 是一个 Godot 4.6 麻辣烫经营原型。玩家从标题页进入主页与选关页，在经营场景里移动到不同站点完成开店、点单、备餐、配送、补货、打烊和结算。

当前项目仍处在原型和重构并行阶段：`scenes/gameplay/game_manager.gd` 仍是主要兼容协调器，但营业日、顾客队列和结算摘要等逻辑已经开始拆入 `gameplay/systems/`。

## 已实现功能

- 菜单流程：标题页、主页、选关页、进入经营场景。
- 玩家移动与站点交互：柜台、仓库、锅、配送点、应急采购、主食篮、礼物盒。
- 营业流程：开店、打烊、自动结束营业、收摊清理阶段、进入日结。
- 顾客流程：顾客生成、排队、耐心流失、离开、特殊顾客标记。
- 订单流程：查看订单、收银、即时交付、等待烹饪/配送。
- 库存系统：熟食库存、生食库存、主食库存。
- 烹饪系统：大锅批量煮配菜、主食漏勺、等待订单交付。
- 补货系统：普通供应商补货、应急采购。
- 经济与声望：资金、今日收入、轮次收入、支出、声望变化。
- 结算系统：日结、轮结、剩余库存展示、进入下一天或返回主页。
- 夜间系统：特殊顾客回响、卡牌选择、当前效果记录。
- 结算互动：剩菜喂猫、摸猫反应。
- 全局菜单：经营场景中按 Tab 查看当前效果与未打开回响。

## 目录说明

- `project.godot`: Godot 项目配置。主场景是 `res://scenes/menus/title_menu.tscn`，autoload 也在这里注册。
- `autoload/`: 全局单例脚本。
  - `progress_data.gd`: 长期进度，例如二号锅、订单面板等级。
  - `run_setup_data.gd`: 当前 run 状态，例如关卡、天数、资金、库存、特殊顾客、回响、日结数据。
  - `text_db.gd`: 读取 `data/text_db.json`，提供 UI 文案和物品名。
  - `effect_manager.gd`: 读取 `data/card_db.json`，提供卡牌效果和 modifier 计算。
  - `global_run_menu.gd`: 经营场景中的 Tab 全局菜单。
- `data/`: 数据文件。
  - `text_db.json`: 中英文 UI 文案。
  - `card_db.json`: 夜间卡牌池、卡牌名称、描述和 modifier。
- `scenes/menus/`: 标题页、主页、选关页。
- `scenes/gameplay/`: 主经营场景、玩家、顾客、`GameManager`。
- `scenes/stations/`: 站点交互分发脚本。
- `scenes/ui/`: HUD 与待处理订单卡。
- `scenes/settlement/`: 日结/轮结页面、喂猫区域、可拖拽剩菜按钮。
- `gameplay/systems/`: 正在拆分出的玩法系统。部分系统已经承接真实逻辑，部分仍是预留接口。
- `gameplay/models/`: 玩法常量和工具，例如物品 id、订单结果常量、库存工具。

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

运行时可以关注 `GameManager.debug_validate_runtime()` 的输出。它会检查关键节点、autoload、库存字典、队列数组和 system 状态，并通过 `push_warning` / `push_error` 给出提示。

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
- 修改初始库存：当前主要看 `scenes/gameplay/game_manager.gd` 中的 planned stock 字典，以及 `autoload/run_setup_data.gd` 的 run 库存。
- 修改供应商基础价格、包裹数量、应急采购倍率：改 `autoload/run_setup_data.gd`。
- 库存逻辑后续应逐步迁入 `gameplay/systems/inventory_system.gd`。

### 顾客和队列

- 修改顾客移动、耐心、订单内容、特殊顾客显示：改 `scenes/gameplay/customer.gd`。
- 修改顾客生成、队列位置、特殊顾客计划应用：改 `gameplay/systems/customer_queue_system.gd`。
- 修改每日特殊顾客计划：改 `autoload/run_setup_data.gd` 的 `setup_daily_special_customer_plan()`。

### 营业流程

- 修改营业时间、开店、打烊、收摊清理、进入日结条件：改 `gameplay/systems/business_day_system.gd`。
- `GameManager` 中保留同名 wrapper，外部站点仍可调用 `open_business()`、`close_business()` 等方法。

### 订单、收银和配送

- 当前主要逻辑仍在 `scenes/gameplay/game_manager.gd`：
  - `begin_checkout_for_customer()`
  - `confirm_checkout_and_create_order()`
  - `route_customer_after_payment()`
  - `interact_with_delivery_point()`
  - `complete_delivery_for_customer()`
  - `get_pending_order_card_data()`
- 后续迁移目标是 `gameplay/systems/order_system.gd`。

### 烹饪

- 大锅 UI、配菜烹饪、容量、主食漏勺、主食提交目前仍主要在 `scenes/gameplay/game_manager.gd`。
- 后续迁移目标是 `gameplay/systems/cooking_system.gd`。
- 与大锅相关的函数通常带有 `cart_pot`，与主食漏勺相关的函数通常带有 `staple_ladle`。

### 补货和应急采购

- 普通补货面板、供应商订单和送达目前仍主要在 `scenes/gameplay/game_manager.gd`。
- 后续迁移目标是 `gameplay/systems/supplier_system.gd`。
- 应急采购、缺货聚合、采购后刷新顾客状态目前仍主要在 `game_manager.gd`。
- 后续迁移目标是 `gameplay/systems/emergency_purchase_system.gd`。

### 声望、回响和卡牌

- 声望变化和特殊顾客结果当前仍主要在 `scenes/gameplay/game_manager.gd`。
- 后续迁移目标是 `gameplay/systems/reputation_system.gd`。
- 特殊顾客回响保存和每日统计：改 `autoload/run_setup_data.gd`。
- 卡牌数据：改 `data/card_db.json`。
- 卡牌读取和 modifier 计算：改 `autoload/effect_manager.gd`。

### UI 和结算

- HUD 金钱、库存、耐心、营业状态、待处理订单：改 `scenes/ui/ui_layer.gd`。
- 待处理订单卡片：改 `scenes/ui/pending_order_card.gd` 和 `pending_order_card.tscn`。
- 日结/轮结页面、夜间抽卡、喂猫：改 `scenes/settlement/settlement_result.gd`。
- 日结/轮结 summary 构建：改 `gameplay/systems/settlement_builder.gd`。

### 文案

- UI 文案优先改 `data/text_db.json`。
- 如果新增物品或状态，需要同步 `autoload/text_db.gd` 中的 `item_key_map` 或 `status_key_map`。
- 代码里仍有部分硬编码中文，后续应逐步迁入 `text_db.json`。
