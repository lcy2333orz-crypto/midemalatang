extends Node

@export var customer_scene: PackedScene

var queued_customers: Array = []
var pending_customers: Array = []

var money: int = 0
var round_income: int = 0
var round_index: int = 1
var today_income: int = 0

var round_gross_income: int = 0
var round_expense: int = 0
var today_gross_income: int = 0
var today_expense: int = 0

var is_open_for_business: bool = false
var is_round_closing: bool = false
var is_cleanup_phase: bool = false
var has_round_finished: bool = false

var day_duration_seconds: float = 15.0
var day_time_left: float = 90.0
var auto_close_triggered: bool = false

var morning_info_layer: CanvasLayer = null
var base_spawn_timer_wait_time: float = 1.0

var day_gift_layer: CanvasLayer = null
var day_gift_panel: Panel = null
var day_gift_current_gift_id: String = ""
var day_gift_current_options: Array = []

var planned_raw_stock: Dictionary = {
	"spinach": 0,
	"potato_slice": 0,
	"tofu_puff": 0
}

var planned_cooked_stock: Dictionary = {
	"spinach": 0,
	"potato_slice": 0,
	"tofu_puff": 0
}

var planned_staple_stock: Dictionary = {
	"glass_noodle": 0,
	"noodle": 0
}

var raw_stock: Dictionary = {}
var cooked_stock: Dictionary = {}
var staple_stock: Dictionary = {}

# 推车阶段：大锅批量煮配菜
var cart_pot_capacity: int = 6
var cart_pot_batch_duration: float = 3.0
var cart_pot_is_cooking: bool = false
var cart_pot_time_left: float = 0.0
var cart_pot_cooking_batch: Dictionary = {}
var cart_pot_selection: Dictionary = {}

var cart_pot_layer: CanvasLayer = null
var cart_pot_panel: Panel = null
var cart_pot_scroll: ScrollContainer = null
var cart_pot_content: VBoxContainer = null

var cart_pot_status_label: Label = null
var cart_pot_row_labels: Dictionary = {}
var cart_pot_minus_buttons: Dictionary = {}
var cart_pot_plus_buttons: Dictionary = {}
var cart_pot_max_buttons: Dictionary = {}
var cart_pot_start_button: Button = null

# 推车阶段：主食漏勺
var staple_ladle_duration: float = 3.0
var staple_ladle_slots: Array = []
var held_raw_staple_food_id: String = ""
var held_staple_food_id: String = ""


var supplier_order_layer: CanvasLayer = null
var supplier_order_panel: Panel = null
var supplier_order_status_label: Label = null
var supplier_order_buttons: Array[Button] = []
var supplier_orders: Array = []
var supplier_order_sequence_id: int = 0
var has_opened_for_business_today: bool = false

var max_queue_size: int = 3

# 多锅系统
var total_cooker_slots: int = 2
var unlocked_cooker_slots: int = 1
var cooker_duration: float = 3.0
var cooker_slots: Array = []

# 订单挂件升级层级
# 0 = 基础挂件（主食/食材/耐心）
# 1 = 显示状态
# 2 = 显示状态 + 锅位
# 3 = 显示状态 + 锅位 + 送餐目标（先留接口）
var order_panel_upgrade_level: int = 0

# 其他升级 / 局内屏蔽
var has_second_cooker: bool = false
var order_panel_blocked_for_this_run: bool = false

@onready var spawn_timer: Timer = $SpawnTimer
@onready var characters_node: Node = $"../Characters"
@onready var customer_spawn: Marker2D = $"../Spawns/CustomerSpawn"

@onready var queue_spot_1: Marker2D = $"../Spawns/QueueSpot1"
@onready var queue_spot_2: Marker2D = $"../Spawns/QueueSpot2"
@onready var queue_spot_3: Marker2D = $"../Spawns/QueueSpot3"

@onready var slot_a: Marker2D = $"../LayoutSlots/SlotA"
@onready var slot_b: Marker2D = $"../LayoutSlots/SlotB"
@onready var slot_c: Marker2D = $"../LayoutSlots/SlotC"
@onready var slot_d: Marker2D = $"../LayoutSlots/SlotD"
@onready var slot_e: Marker2D = $"../LayoutSlots/SlotE"
@onready var slot_f: Marker2D = $"../LayoutSlots/SlotF"

@onready var counter_node: Node2D = $"../Stations/Counter"
@onready var delivery_node: Node2D = $"../Stations/DeliveryPoint"
@onready var storage_node: Node2D = $"../Stations/StorageArea"
@onready var cooker_1_node: Node2D = $"../Stations/Cooker"
@onready var cooker_2_node: Node2D = null
@onready var emergency_shop_node: Node2D = $"../Stations/EmergencyShop"

func _ready() -> void:
	print("GameManager ready")
	print("customer_scene: ", customer_scene)
	print("characters_node: ", characters_node)
	print("customer_spawn: ", customer_spawn)
	print("queue_spot_1: ", queue_spot_1)
	print("queue_spot_2: ", queue_spot_2)
	print("queue_spot_3: ", queue_spot_3)

	if spawn_timer != null:
		base_spawn_timer_wait_time = spawn_timer.wait_time
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	_apply_upgrade_flags()
	initialize_cooker_slots()
	start_round()

func _process(delta: float) -> void:
	update_day_timer(delta)
	update_supplier_orders(delta)
	update_cooker_slots(delta)
	update_cart_pot(delta)
	update_staple_ladle_slots(delta)

	if is_round_closing and not has_round_finished and not is_cleanup_phase:
		try_finish_day()

	var game_ui = get_tree().get_first_node_in_group("game_ui")
	if game_ui == null:
		return

	game_ui.update_business_state(
		day_time_left,
		is_open_for_business,
		is_round_closing,
		has_round_finished,
		is_cleanup_phase
	)

	game_ui.hide_patience()

	var order_cards: Array = []
	for customer in pending_customers:
		if customer != null and is_instance_valid(customer):
			if not customer.order_served:
				order_cards.append(get_pending_order_card_data(customer))

	if order_cards.is_empty():
		game_ui.hide_pending_orders()
	else:
		game_ui.show_pending_orders(order_cards)

func update_day_timer(delta: float) -> void:
	if has_round_finished:
		return

	if is_round_closing:
		return

	day_time_left = max(day_time_left - delta, 0.0)

	if day_time_left <= 0.0 and not auto_close_triggered:
		auto_close_triggered = true
		print("=== 营业时间已到，自动打烊 ===")

		if is_open_for_business:
			close_business()
		else:
			force_close_day_before_opening()

func force_close_day_before_opening() -> void:
	is_open_for_business = false
	is_round_closing = true
	day_time_left = 0.0

	if spawn_timer != null and is_instance_valid(spawn_timer):
		spawn_timer.stop()

	print("=== 今日时间已耗尽，进入收摊整理 ===")
	try_finish_day()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("round_summary"):
		print_round_summary()

func _apply_upgrade_flags() -> void:
	has_second_cooker = ProgressData.has_second_cooker
	order_panel_upgrade_level = ProgressData.order_panel_upgrade_level

	if has_second_cooker:
		unlocked_cooker_slots = 2
	else:
		unlocked_cooker_slots = 1

func start_round() -> void:
	RunSetupData.ensure_starting_money_for_new_run()

	initialize_round_stocks()
	activate_and_apply_current_day_business_event()

	_apply_upgrade_flags()
	initialize_cooker_slots()
	initialize_staple_ladle_slots()
	apply_station_layout_from_run_setup()

	money = RunSetupData.run_money
	round_income = RunSetupData.run_total_income
	round_gross_income = RunSetupData.run_gross_income
	round_expense = RunSetupData.run_total_expense

	today_income = 0
	today_gross_income = 0
	today_expense = 0

	is_open_for_business = false
	is_round_closing = false
	is_cleanup_phase = false
	has_round_finished = false

	has_opened_for_business_today = false
	supplier_orders.clear()
	supplier_order_sequence_id = 0
	close_supplier_order_panel()

	day_time_left = day_duration_seconds
	auto_close_triggered = false

	RunSetupData.today_special_customer_results = []
	RunSetupData.generated_night_queue = []
	RunSetupData.today_reputation_delta = 0
	RunSetupData.reset_today_stall_echo_stats()

	RunSetupData.setup_daily_special_customer_plan()

	print("=== 当前天开始 ===")
	print("Day: ", RunSetupData.current_day_in_run, "/", RunSetupData.total_days_in_run)
	print("Selected stage id: ", RunSetupData.selected_stage_id)
	print("Selected difficulty days: ", RunSetupData.selected_difficulty_days)
	print("Station layout from RunSetupData: ", RunSetupData.station_layout)
	print("Current day business event: ", RunSetupData.current_day_business_event)
	print("Starting / current money: ", money)
	print_stocks()

	var game_ui = get_tree().get_first_node_in_group("game_ui")

	if game_ui:
		game_ui.update_money(money)
		game_ui.hide_order()
		game_ui.hide_stock()
		game_ui.hide_patience()
		game_ui.hide_pending_orders()
		game_ui.update_business_state(
			day_time_left,
			is_open_for_business,
			is_round_closing,
			has_round_finished,
			is_cleanup_phase
		)

	queued_customers.clear()
	pending_customers.clear()

	if spawn_timer != null and is_instance_valid(spawn_timer):
		spawn_timer.stop()

	print("当前未开业，不生成普通顾客。")

	show_pending_morning_info_if_any()

func can_use_supplier_ordering() -> bool:
	if has_round_finished:
		return false

	if is_round_closing:
		return false

	if is_cleanup_phase:
		return false

	if is_open_for_business:
		return false

	if has_opened_for_business_today:
		return false

	return true


func open_supplier_order_panel() -> void:
	if not can_use_supplier_ordering():
		print("普通供货商只在开业前接单。开业后只能去 EmergencyShop 找隔壁临时借货。")
		show_storage_stock_only()
		return

	if supplier_order_layer != null and is_instance_valid(supplier_order_layer):
		refresh_supplier_order_panel()
		return

	supplier_order_layer = CanvasLayer.new()
	supplier_order_layer.name = "SupplierOrderLayer"
	supplier_order_layer.layer = 90
	add_child(supplier_order_layer)

	var viewport_size := get_viewport().get_visible_rect().size

	supplier_order_panel = Panel.new()
	supplier_order_panel.name = "SupplierOrderPanel"
	supplier_order_panel.size = Vector2(640, 430)
	supplier_order_panel.position = Vector2(
		viewport_size.x * 0.5 - 320,
		viewport_size.y * 0.5 - 215
	)
	supplier_order_layer.add_child(supplier_order_panel)

	var title_label := Label.new()
	title_label.name = "SupplierOrderTitle"
	title_label.text = "早市供货商"
	title_label.position = Vector2(24, 14)
	title_label.size = Vector2(592, 32)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	supplier_order_panel.add_child(title_label)

	var desc_label := Label.new()
	desc_label.name = "SupplierOrderDesc"
	desc_label.text = "开业前可以批量订货。食材和主食都按篮/箱送达；开业后供货商就不接单了。"
	desc_label.position = Vector2(36, 48)
	desc_label.size = Vector2(568, 44)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 13)
	supplier_order_panel.add_child(desc_label)

	supplier_order_status_label = Label.new()
	supplier_order_status_label.name = "SupplierOrderStatus"
	supplier_order_status_label.position = Vector2(34, 92)
	supplier_order_status_label.size = Vector2(572, 108)
	supplier_order_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	supplier_order_status_label.add_theme_font_size_override("font_size", 13)
	supplier_order_panel.add_child(supplier_order_status_label)

	supplier_order_buttons.clear()

	var item_ids := RunSetupData.get_supplier_order_item_ids()
	var package_options := RunSetupData.get_supplier_package_options()

	var start_x := 34
	var start_y := 210
	var button_w := 112
	var button_h := 48
	var gap_x := 8
	var gap_y := 10

	var button_index := 0

	for item_id in item_ids:
		for package_data in package_options:
			if typeof(package_data) != TYPE_DICTIONARY:
				continue

			var amount := int(package_data.get("amount", 1))
			var package_id := str(package_data.get("id", "package"))
			var package_name := str(package_data.get("name", "一批"))

			var button := Button.new()
			button.name = "Order_%s_%s_Button" % [item_id, package_id]
			button.position = Vector2(
				start_x + (button_index % 5) * (button_w + gap_x),
				start_y + int(button_index / 5) * (button_h + gap_y)
			)
			button.size = Vector2(button_w, button_h)
			button.mouse_filter = Control.MOUSE_FILTER_STOP

			button.set_meta("item_id", item_id)
			button.set_meta("amount", amount)
			button.set_meta("package_name", package_name)

			button.pressed.connect(_on_supplier_order_button_pressed.bind(item_id, amount))

			supplier_order_panel.add_child(button)
			supplier_order_buttons.append(button)

			button_index += 1

	var close_button := Button.new()
	close_button.name = "SupplierOrderCloseButton"
	close_button.text = "关闭"
	close_button.position = Vector2(250, 370)
	close_button.size = Vector2(140, 42)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(close_supplier_order_panel)
	supplier_order_panel.add_child(close_button)

	refresh_supplier_order_panel()

func refresh_supplier_order_panel() -> void:
	if supplier_order_panel == null:
		return

	if supplier_order_status_label != null:
		var lines: Array[String] = []

		lines.append("当前资金：%d" % money)
		lines.append("生食材：%s" % get_raw_stock_text())
		lines.append("主食库存：%s" % get_staple_stock_text())

		if supplier_orders.is_empty():
			lines.append("待送达：无")
		else:
			lines.append("待送达：")

			for order_data in supplier_orders:
				if typeof(order_data) != TYPE_DICTIONARY:
					continue

				var order_items: Dictionary = order_data.get("items", {})
				var time_left := float(order_data.get("time_left", 0.0))

				lines.append("- %s，约 %.1f 秒后送达" % [
					get_items_text(order_items),
					time_left
				])

		supplier_order_status_label.text = "\n".join(lines)

	for button in supplier_order_buttons:
		if button == null or not is_instance_valid(button):
			continue

		var item_id := str(button.get_meta("item_id", ""))
		var amount := int(button.get_meta("amount", 1))
		var package_name := str(button.get_meta("package_name", "一批"))

		if item_id == "":
			continue

		var price := RunSetupData.get_supplier_order_price(item_id, amount)
		var current_amount := 0

		if RunSetupData.is_staple_item(item_id):
			current_amount = int(staple_stock.get(item_id, 0))
		else:
			current_amount = int(raw_stock.get(item_id, 0))

		var pending_amount := get_pending_supplier_order_amount(item_id)
		var display_name := get_ingredient_display_name(item_id)

		if pending_amount > 0:
			button.text = "%s %s x%d\n%d金｜库%d 待%d" % [
				display_name,
				package_name,
				amount,
				price,
				current_amount,
				pending_amount
			]
		else:
			button.text = "%s %s x%d\n%d金｜库存%d" % [
				display_name,
				package_name,
				amount,
				price,
				current_amount
			]

		button.disabled = money < price or not can_use_supplier_ordering()

func close_supplier_order_panel() -> void:
	if supplier_order_layer != null and is_instance_valid(supplier_order_layer):
		supplier_order_layer.queue_free()

	supplier_order_layer = null
	supplier_order_panel = null
	supplier_order_status_label = null
	supplier_order_buttons.clear()


func get_pending_supplier_order_amount(item_id: String) -> int:
	var total := 0

	for order_data in supplier_orders:
		if typeof(order_data) != TYPE_DICTIONARY:
			continue

		var items = order_data.get("items", {})

		if typeof(items) != TYPE_DICTIONARY:
			continue

		total += int(items.get(item_id, 0))

	return total


func _on_supplier_order_button_pressed(item_id: String, amount: int = 1) -> void:
	if not can_use_supplier_ordering():
		print("普通供货商只在开业前接单。")
		refresh_supplier_order_panel()
		return

	var price := RunSetupData.get_supplier_order_price(item_id, amount)

	if not spend_money(price):
		print("订货失败，资金不足。")
		refresh_supplier_order_panel()
		return

	supplier_order_sequence_id += 1

	var order_data := {
		"order_id": "supplier_order_%d" % supplier_order_sequence_id,
		"items": {
			item_id: amount
		},
		"time_left": RunSetupData.get_supplier_delivery_seconds()
	}

	supplier_orders.append(order_data)

	print("Supplier order placed: ", order_data)
	print("Supplier order cost: ", price)

	refresh_supplier_order_panel()


func update_supplier_orders(delta: float) -> void:
	if supplier_orders.is_empty():
		return

	var delivered_orders: Array = []

	for i in range(supplier_orders.size()):
		var order_data: Dictionary = supplier_orders[i]

		var time_left := float(order_data.get("time_left", 0.0))
		time_left -= delta
		order_data["time_left"] = time_left
		supplier_orders[i] = order_data

		if time_left <= 0.0:
			delivered_orders.append(order_data)

	for order_data in delivered_orders:
		deliver_supplier_order(order_data)
		supplier_orders.erase(order_data)

	if supplier_order_layer != null and is_instance_valid(supplier_order_layer):
		refresh_supplier_order_panel()


func deliver_supplier_order(order_data: Dictionary) -> void:
	var items = order_data.get("items", {})

	if typeof(items) != TYPE_DICTIONARY:
		return

	for item_id in items.keys():
		var amount := int(items.get(item_id, 0))
		var item_key := str(item_id)

		if amount <= 0:
			continue

		if RunSetupData.is_staple_item(item_key):
			if not staple_stock.has(item_key):
				staple_stock[item_key] = 0

			staple_stock[item_key] = int(staple_stock.get(item_key, 0)) + amount
		else:
			if not raw_stock.has(item_key):
				raw_stock[item_key] = 0

			raw_stock[item_key] = int(raw_stock.get(item_key, 0)) + amount

	RunSetupData.current_raw_stock = raw_stock.duplicate(true)
	RunSetupData.current_staple_stock = staple_stock.duplicate(true)

	print("Supplier order delivered: ", items)
	print("Raw stock after supplier delivery: ", raw_stock)
	print("Staple stock after supplier delivery: ", staple_stock)

	if supplier_order_layer != null and is_instance_valid(supplier_order_layer):
		refresh_supplier_order_panel()

func open_cart_pot_panel() -> void:
	if cart_pot_layer != null and is_instance_valid(cart_pot_layer):
		refresh_cart_pot_panel()
		return

	cart_pot_layer = CanvasLayer.new()
	cart_pot_layer.name = "CartPotLayer"
	cart_pot_layer.layer = 95
	add_child(cart_pot_layer)

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	cart_pot_panel = Panel.new()
	cart_pot_panel.name = "CartPotPanel"
	cart_pot_panel.size = Vector2(720, 430)
	cart_pot_panel.position = Vector2(
		viewport_size.x * 0.5 - 360,
		viewport_size.y * 0.5 - 215
	)
	cart_pot_layer.add_child(cart_pot_panel)

	var title_label := Label.new()
	title_label.name = "CartPotTitle"
	title_label.text = "大锅：批量煮配菜"
	title_label.position = Vector2(24, 14)
	title_label.size = Vector2(672, 32)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	cart_pot_panel.add_child(title_label)

	var desc_label := Label.new()
	desc_label.name = "CartPotDesc"
	desc_label.text = "选择这次要加入大锅的配菜数量。关上锅盖后，如果本次准备不为空，就会自动开始煮。"
	desc_label.position = Vector2(40, 48)
	desc_label.size = Vector2(640, 42)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 13)
	cart_pot_panel.add_child(desc_label)

	cart_pot_status_label = Label.new()
	cart_pot_status_label.name = "CartPotStatus"
	cart_pot_status_label.position = Vector2(36, 94)
	cart_pot_status_label.size = Vector2(648, 96)
	cart_pot_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cart_pot_status_label.add_theme_font_size_override("font_size", 13)
	cart_pot_panel.add_child(cart_pot_status_label)

	cart_pot_row_labels.clear()
	cart_pot_minus_buttons.clear()
	cart_pot_plus_buttons.clear()
	cart_pot_max_buttons.clear()

	var item_ids: Array = get_cart_pot_ingredient_ids()
	var start_y: int = 205
	var row_h: int = 46

	for i in range(item_ids.size()):
		var item_id: String = str(item_ids[i])
		var row_y: int = start_y + i * row_h

		var row_label := Label.new()
		row_label.name = "CartPot_%s_Label" % item_id
		row_label.position = Vector2(40, row_y)
		row_label.size = Vector2(360, 34)
		row_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row_label.add_theme_font_size_override("font_size", 15)
		cart_pot_panel.add_child(row_label)
		cart_pot_row_labels[item_id] = row_label

		var minus_button := Button.new()
		minus_button.name = "CartPot_%s_MinusButton" % item_id
		minus_button.text = "-"
		minus_button.position = Vector2(420, row_y)
		minus_button.size = Vector2(48, 34)
		minus_button.pressed.connect(_on_cart_pot_minus_pressed.bind(item_id))
		cart_pot_panel.add_child(minus_button)
		cart_pot_minus_buttons[item_id] = minus_button

		var plus_button := Button.new()
		plus_button.name = "CartPot_%s_PlusButton" % item_id
		plus_button.text = "+"
		plus_button.position = Vector2(478, row_y)
		plus_button.size = Vector2(48, 34)
		plus_button.pressed.connect(_on_cart_pot_plus_pressed.bind(item_id))
		cart_pot_panel.add_child(plus_button)
		cart_pot_plus_buttons[item_id] = plus_button

		var max_button := Button.new()
		max_button.name = "CartPot_%s_MaxButton" % item_id
		max_button.text = "最大"
		max_button.position = Vector2(538, row_y)
		max_button.size = Vector2(72, 34)
		max_button.pressed.connect(_on_cart_pot_max_pressed.bind(item_id))
		cart_pot_panel.add_child(max_button)
		cart_pot_max_buttons[item_id] = max_button

	cart_pot_start_button = null

	var close_button := Button.new()
	close_button.name = "CartPotCloseButton"
	close_button.text = "盖上锅盖"
	close_button.position = Vector2(290, 360)
	close_button.size = Vector2(140, 42)
	close_button.pressed.connect(close_cart_pot_panel_and_auto_start)
	cart_pot_panel.add_child(close_button)

	refresh_cart_pot_panel()

func _build_ladle_row(ladle_index: int) -> HBoxContainer:
	var slot_index: int = ladle_index - 1

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var state_label := Label.new()
	state_label.custom_minimum_size = Vector2(190, 28)
	state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state_label.text = _get_ladle_state_text(ladle_index)
	row.add_child(state_label)

	var slot_state: String = "empty"

	if slot_index >= 0 and slot_index < staple_ladle_slots.size():
		var slot: Dictionary = staple_ladle_slots[slot_index] as Dictionary
		slot_state = str(slot.get("state", "empty"))

	var cook_glass_button := Button.new()
	cook_glass_button.text = "煮粉丝"
	cook_glass_button.custom_minimum_size = Vector2(74, 28)
	cook_glass_button.disabled = not can_start_staple_ladle_cooking(slot_index, "glass_noodle")
	row.add_child(cook_glass_button)

	var cook_noodle_button := Button.new()
	cook_noodle_button.text = "煮面"
	cook_noodle_button.custom_minimum_size = Vector2(74, 28)
	cook_noodle_button.disabled = not can_start_staple_ladle_cooking(slot_index, "noodle")
	row.add_child(cook_noodle_button)

	var take_out_button := Button.new()
	take_out_button.text = "取出"
	take_out_button.custom_minimum_size = Vector2(64, 28)
	take_out_button.disabled = slot_state != "ready" or held_staple_food_id != ""
	row.add_child(take_out_button)

	return row

func _get_ladle_state_text(ladle_index: int) -> String:
	var slot_index := ladle_index - 1

	if slot_index < 0 or slot_index >= staple_ladle_slots.size():
		return "漏勺%d：空" % ladle_index

	return get_staple_ladle_text(slot_index)

func request_cart_pot_panel_refresh() -> void:
	if cart_pot_panel == null or not is_instance_valid(cart_pot_panel):
		return

	call_deferred("refresh_cart_pot_panel")

func refresh_cart_pot_panel() -> void:
	if cart_pot_panel == null:
		return

	if cart_pot_status_label != null:
		var lines: Array[String] = []
		lines.append("大锅容量：%d / %d" % [
			get_cart_pot_total_capacity_with_selection(),
			cart_pot_capacity
		])
		lines.append("锅中熟配菜：%s" % get_cooked_stock_text())

		if cart_pot_is_cooking:
			lines.append("正在煮：%s，剩余 %.1f 秒" % [
				get_items_text(cart_pot_cooking_batch),
				max(cart_pot_time_left, 0.0)
			])
		else:
			lines.append("正在煮：无")

		if cart_pot_selection.is_empty():
			lines.append("本次准备：无")
		else:
			lines.append("本次准备：%s" % get_items_text(cart_pot_selection))

		cart_pot_status_label.text = "\n".join(lines)

	var disabled_by_cooking := cart_pot_is_cooking

	for item_id in get_cart_pot_ingredient_ids():
		var item_key := str(item_id)
		var raw_amount := int(raw_stock.get(item_key, 0))
		var cooked_amount := int(cooked_stock.get(item_key, 0))
		var selected_amount := int(cart_pot_selection.get(item_key, 0))
		var display_name := get_ingredient_display_name(item_key)

		if cart_pot_row_labels.has(item_key):
			var row_label: Label = cart_pot_row_labels[item_key]
			row_label.text = "%s 生 x%d 锅中熟 x%d 本次煮 x%d" % [
				display_name,
				raw_amount,
				cooked_amount,
				selected_amount
			]

		if cart_pot_minus_buttons.has(item_key):
			var minus_button: Button = cart_pot_minus_buttons[item_key]
			minus_button.disabled = disabled_by_cooking or selected_amount <= 0

		if cart_pot_plus_buttons.has(item_key):
			var plus_button: Button = cart_pot_plus_buttons[item_key]
			plus_button.disabled = not can_add_to_cart_pot_selection(item_key, 1)

		if cart_pot_max_buttons.has(item_key):
			var max_button: Button = cart_pot_max_buttons[item_key]
			max_button.disabled = (
				disabled_by_cooking
				or raw_amount <= selected_amount
				or get_cart_pot_available_capacity_for_selection() <= 0
			)

func close_cart_pot_panel_and_auto_start() -> void:
	if cart_pot_is_cooking:
		print("大锅正在烹饪中，关闭面板。")
		close_cart_pot_panel()
		return

	if cart_pot_selection.is_empty():
		print("没有选择要煮的配菜，关闭大锅面板。")
		close_cart_pot_panel()
		return

	print("关闭大锅面板，自动开始烹饪。")
	start_cart_pot_batch_cooking()
	close_cart_pot_panel()

func close_cart_pot_panel() -> void:
	if cart_pot_layer != null and is_instance_valid(cart_pot_layer):
		cart_pot_layer.queue_free()

	cart_pot_layer = null
	cart_pot_panel = null
	cart_pot_status_label = null
	cart_pot_start_button = null

	cart_pot_row_labels.clear()
	cart_pot_minus_buttons.clear()
	cart_pot_plus_buttons.clear()
	cart_pot_max_buttons.clear()


func _on_cart_pot_minus_pressed(item_id: String) -> void:
	if cart_pot_is_cooking:
		print("大锅正在煮，不能调整本次准备。")
		request_cart_pot_panel_refresh()
		return

	var current_amount := int(cart_pot_selection.get(item_id, 0))

	if current_amount <= 0:
		cart_pot_selection.erase(item_id)
		request_cart_pot_panel_refresh()
		return

	current_amount -= 1

	if current_amount <= 0:
		cart_pot_selection.erase(item_id)
	else:
		cart_pot_selection[item_id] = current_amount

	request_cart_pot_panel_refresh()


func _on_cart_pot_plus_pressed(item_id: String) -> void:
	if cart_pot_is_cooking:
		print("大锅正在煮，不能调整本次准备。")
		request_cart_pot_panel_refresh()
		return

	if not can_add_to_cart_pot_selection(item_id, 1):
		print("不能继续加入大锅选择：", item_id)
		request_cart_pot_panel_refresh()
		return

	cart_pot_selection[item_id] = int(cart_pot_selection.get(item_id, 0)) + 1

	request_cart_pot_panel_refresh()


func _on_cart_pot_max_pressed(item_id: String) -> void:
	if cart_pot_is_cooking:
		print("大锅正在煮，不能调整本次准备。")
		request_cart_pot_panel_refresh()
		return

	var raw_amount: int = int(raw_stock.get(item_id, 0))
	var selected_amount: int = int(cart_pot_selection.get(item_id, 0))
	var available_capacity: int = int(get_cart_pot_available_capacity_for_selection())

	var raw_available: int = raw_amount - selected_amount
	var can_add_amount: int = min(raw_available, available_capacity)

	if can_add_amount <= 0:
		print("没有更多可加入大锅的数量：", item_id)
		request_cart_pot_panel_refresh()
		return

	cart_pot_selection[item_id] = selected_amount + can_add_amount

	request_cart_pot_panel_refresh()


func _on_cart_pot_start_pressed() -> void:
	start_cart_pot_batch_cooking()


func show_storage_stock_only() -> void:
	var game_ui = get_tree().get_first_node_in_group("game_ui")

	if game_ui == null:
		print("Cannot show storage stock. No game_ui found.")
		return

	var cooked_text := get_cooked_stock_text()
	var raw_and_staple_text := "%s\n主食库存：%s" % [
		get_raw_stock_text(),
		get_staple_stock_text()
	]

	game_ui.show_stock(
		cooked_text,
		raw_and_staple_text
	)

	print("Show storage stock only.")
	print("Cooked stock text: ", cooked_text)
	print("Raw / staple stock text: ", raw_and_staple_text)

func interact_with_gift_box() -> void:
	if day_gift_layer != null and is_instance_valid(day_gift_layer):
		print("礼物选择面板已经打开。")
		return

	var unopened_gifts: Array = RunSetupData.get_unopened_pending_gifts()

	if unopened_gifts.is_empty():
		print("礼物盒是空的。当前没有未打开的特殊客人礼物。")
		return

	var gift_data: Dictionary = unopened_gifts[0]
	open_day_gift_choice_panel(gift_data)

func open_day_gift_choice_panel(gift_data: Dictionary) -> void:
	if gift_data.is_empty():
		print("不能打开空礼物。")
		return

	var gift_id: String = str(gift_data.get("gift_id", ""))
	if gift_id == "":
		print("礼物没有 gift_id，不能打开。")
		return

	day_gift_current_gift_id = gift_id

	var saved_options: Array = RunSetupData.get_gift_current_options(gift_id)
	if saved_options.is_empty():
		day_gift_current_options = generate_day_gift_options(gift_data)
		RunSetupData.set_gift_current_options(gift_id, day_gift_current_options)
	else:
		day_gift_current_options = saved_options

	day_gift_layer = CanvasLayer.new()
	day_gift_layer.name = "DayGiftLayer"
	day_gift_layer.layer = 120
	add_child(day_gift_layer)

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	day_gift_panel = Panel.new()
	day_gift_panel.name = "DayGiftPanel"
	day_gift_panel.size = Vector2(720, 360)
	day_gift_panel.position = Vector2(
		viewport_size.x * 0.5 - 360,
		viewport_size.y * 0.5 - 180
	)
	day_gift_layer.add_child(day_gift_panel)

	var title_label := Label.new()
	title_label.name = "DayGiftTitle"
	title_label.text = str(gift_data.get("display_name", "特殊客人的礼物"))
	title_label.position = Vector2(24, 18)
	title_label.size = Vector2(672, 34)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	day_gift_panel.add_child(title_label)

	var desc_label := Label.new()
	desc_label.name = "DayGiftDesc"
	desc_label.text = "特殊客人留下了一个小小的回响。选择其中一种影响。"
	desc_label.position = Vector2(48, 58)
	desc_label.size = Vector2(624, 44)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 14)
	day_gift_panel.add_child(desc_label)

	for i in range(day_gift_current_options.size()):
		var option_data: Dictionary = day_gift_current_options[i]
		var button := Button.new()
		button.name = "DayGiftOption%d" % i
		button.position = Vector2(42 + i * 226, 125)
		button.size = Vector2(196, 150)
		button.text = get_day_gift_option_button_text(option_data)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_day_gift_option_pressed.bind(i))
		day_gift_panel.add_child(button)

	var close_button := Button.new()
	close_button.name = "DayGiftCloseButton"
	close_button.text = "先不打开"
	close_button.position = Vector2(290, 300)
	close_button.size = Vector2(140, 38)
	close_button.pressed.connect(close_day_gift_choice_panel)
	day_gift_panel.add_child(close_button)

	print("打开白天礼物：", gift_data)
	print("白天礼物选项：", day_gift_current_options)


func close_day_gift_choice_panel() -> void:
	if day_gift_layer != null and is_instance_valid(day_gift_layer):
		day_gift_layer.queue_free()

	day_gift_layer = null
	day_gift_panel = null
	day_gift_current_gift_id = ""
	day_gift_current_options.clear()

func generate_day_gift_options(gift_data: Dictionary) -> Array:
	var result: String = str(gift_data.get("result", "neutral"))
	var source_type: String = str(gift_data.get("source_type", ""))

	if result == "bad":
		return [
			{
				"id": "mouse_bad_slow_start",
				"name": "摊口有点乱",
				"description": "今天顾客等待耐心略微下降。",
				"effect_type": "active_effect"
			},
			{
				"id": "mouse_bad_extra_cost",
				"name": "临时添乱",
				"description": "立刻损失 2 金。",
				"effect_type": "instant_money",
				"money_delta": -2
			},
			{
				"id": "mouse_bad_reputation",
				"name": "小小坏印象",
				"description": "立刻失去 1 点口碑。",
				"effect_type": "instant_reputation",
				"reputation_delta": -1
			}
		]

	if source_type == "mouse":
		return [
			{
				"id": "busy_stall",
				"name": "热闹摊口",
				"description": "顾客来得更快，适合想多做几单的时候。",
				"effect_type": "active_effect"
			},
			{
				"id": "mouse_spare_coin",
				"name": "老鼠的小零钱",
				"description": "立刻获得 2 金。",
				"effect_type": "instant_money",
				"money_delta": 2
			},
			{
				"id": "mouse_found_spinach",
				"name": "老鼠找到的青菜",
				"description": "立刻获得菠菜 x2。",
				"effect_type": "instant_stock",
				"stock_item_id": "spinach",
				"stock_amount": 2
			}
		]

	return [
		{
			"id": "small_tip",
			"name": "一点小心意",
			"description": "立刻获得 1 金。",
			"effect_type": "instant_money",
			"money_delta": 1
		},
		{
			"id": "warm_memory",
			"name": "温热回响",
			"description": "立刻获得 1 点口碑。",
			"effect_type": "instant_reputation",
			"reputation_delta": 1
		},
		{
			"id": "steady_paws",
			"name": "稳稳爪爪",
			"description": "记录为一个稳定经营效果。",
			"effect_type": "active_effect"
		}
	]

func _on_day_gift_option_pressed(option_index: int) -> void:
	if day_gift_current_gift_id == "":
		print("没有正在打开的礼物。")
		return

	if option_index < 0 or option_index >= day_gift_current_options.size():
		print("礼物选项编号无效：", option_index)
		return

	var chosen_card: Dictionary = day_gift_current_options[option_index]
	var gift_data: Dictionary = RunSetupData.get_unopened_gift_by_id(day_gift_current_gift_id)

	if gift_data.is_empty():
		print("这个礼物已经被打开，或者找不到。")
		close_day_gift_choice_panel()
		return

	apply_day_gift_choice(gift_data, chosen_card)
	RunSetupData.mark_gift_opened(day_gift_current_gift_id, chosen_card)

	print("白天打开礼物，选择：", chosen_card)

	close_day_gift_choice_panel()


func apply_day_gift_choice(gift_data: Dictionary, chosen_card: Dictionary) -> void:
	var effect_type: String = str(chosen_card.get("effect_type", "active_effect"))
	var card_id: String = str(chosen_card.get("id", "unknown_card"))
	var card_name: String = str(chosen_card.get("name", "未知卡牌"))
	var gift_id: String = str(gift_data.get("gift_id", ""))
	var display_name: String = str(gift_data.get("display_name", "特殊客人的礼物"))
	var result: String = str(gift_data.get("result", "neutral"))

	if effect_type == "instant_money":
		var money_delta: int = int(chosen_card.get("money_delta", 0))

		if money_delta >= 0:
			add_money(money_delta)
		else:
			var cost: int = abs(money_delta)
			if not spend_money(cost):
				print("即时金钱惩罚无法完全支付。需要：", cost, " 当前：", money)

	elif effect_type == "instant_reputation":
		var reputation_delta: int = int(chosen_card.get("reputation_delta", 0))
		if reputation_delta != 0:
			change_reputation(reputation_delta, "day gift")

	elif effect_type == "instant_stock":
		var item_id: String = str(chosen_card.get("stock_item_id", ""))
		var amount: int = int(chosen_card.get("stock_amount", 0))

		if item_id != "" and amount > 0:
			if RunSetupData.is_staple_item(item_id):
				staple_stock[item_id] = int(staple_stock.get(item_id, 0)) + amount
				RunSetupData.current_staple_stock = staple_stock.duplicate(true)
			else:
				raw_stock[item_id] = int(raw_stock.get(item_id, 0)) + amount
				RunSetupData.current_raw_stock = raw_stock.duplicate(true)

			print("礼物获得库存：", get_ingredient_display_name(item_id), " x", amount)

	else:
		RunSetupData.active_effects.append({
			"source": display_name,
			"type": "special_echo",
			"result": result,
			"effect_id": card_id,
			"effect": card_name,
			"from_gift_id": gift_id
		})

	print("当前已获得效果列表：", RunSetupData.active_effects)

func get_day_gift_option_button_text(option_data: Dictionary) -> String:
	var name: String = str(option_data.get("name", "未知卡牌"))
	var desc: String = str(option_data.get("description", ""))
	return "%s\n\n%s" % [name, desc]

func get_ingredient_display_name(item_id: String) -> String:
	return TextDB.get_item_name(item_id)


func get_items_text(items: Dictionary) -> String:
	var parts: Array[String] = []

	for item_id in items.keys():
		var amount := int(items.get(item_id, 0))

		if amount <= 0:
			continue

		parts.append("%s x%d" % [
			get_ingredient_display_name(str(item_id)),
			amount
		])

	if parts.is_empty():
		return "无"

	return "，".join(parts)

func activate_and_apply_current_day_business_event() -> void:
	var event := RunSetupData.activate_pending_tomorrow_event()

	if event.is_empty():
		return

	print("Activated tomorrow business event: ", event)

	var raw_bonus := int(RunSetupData.get_current_day_additive("random_raw_stock_bonus", 0.0))

	if raw_bonus > 0:
		apply_random_raw_stock_bonus(raw_bonus)

func apply_random_raw_stock_bonus(amount: int) -> void:
	if amount <= 0:
		return

	var item_pool: Array[String] = RunSetupData.get_basic_ingredient_ids()

	if item_pool.is_empty():
		return

	var gained: Dictionary = {}

	for i in range(amount):
		var item_id := item_pool[randi() % item_pool.size()]

		if not raw_stock.has(item_id):
			raw_stock[item_id] = 0

		raw_stock[item_id] = int(raw_stock[item_id]) + 1
		gained[item_id] = int(gained.get(item_id, 0)) + 1

	RunSetupData.current_raw_stock = raw_stock.duplicate(true)

	print("Morning raw stock bonus applied: ", gained)
	print("Raw stock after morning bonus: ", raw_stock)

func get_modified_spawn_timer_wait_time() -> float:
	var multiplier := RunSetupData.get_current_day_multiplier(
		"customer_spawn_interval_multiplier",
		1.0
	)

	return max(base_spawn_timer_wait_time * multiplier, 0.2)

func start_spawn_timer_if_needed() -> void:
	if not can_spawn_customers_now():
		return

	if queued_customers.size() >= max_queue_size:
		return

	if spawn_timer == null:
		return

	if not is_instance_valid(spawn_timer):
		return

	if not spawn_timer.is_inside_tree():
		return

	spawn_timer.wait_time = get_modified_spawn_timer_wait_time()
	spawn_timer.start()

	print("Spawn timer started. wait_time=", spawn_timer.wait_time)

func show_pending_morning_info_if_any() -> void:
	var lines := RunSetupData.consume_pending_morning_info_lines()

	if lines.is_empty():
		return

	print("=== 昨晚小猫获得的信息 ===")

	for line in lines:
		print(line)

	_create_morning_info_layer(lines)

func _create_morning_info_layer(lines: Array[String]) -> void:
	if morning_info_layer != null and is_instance_valid(morning_info_layer):
		morning_info_layer.queue_free()

	morning_info_layer = CanvasLayer.new()
	morning_info_layer.name = "MorningInfoLayer"
	morning_info_layer.layer = 80
	add_child(morning_info_layer)

	var viewport_size := get_viewport().get_visible_rect().size

	var panel := Panel.new()
	panel.name = "MorningInfoPanel"
	panel.size = Vector2(520, 165)
	panel.position = Vector2(
		viewport_size.x * 0.5 - 260,
		62
	)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	morning_info_layer.add_child(panel)

	var label := Label.new()
	label.name = "MorningInfoLabel"
	label.position = Vector2(20, 16)
	label.size = Vector2(480, 132)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.text = "\n".join(lines)

	panel.add_child(label)

	var tween := create_tween()
	tween.tween_interval(4.2)
	tween.tween_property(panel, "modulate:a", 0.0, 0.8)

	await get_tree().create_timer(5.1).timeout

	if is_instance_valid(morning_info_layer):
		morning_info_layer.queue_free()
		morning_info_layer = null

func _apply_special_customer_plan_to_customer(customer: Node) -> void:
	if customer == null or not is_instance_valid(customer):
		return

	if RunSetupData.current_day_special_spawn_plan.is_empty():
		return

	var next_plan = RunSetupData.current_day_special_spawn_plan.pop_front()

	if typeof(next_plan) != TYPE_DICTIONARY:
		return

	var special_type: String = str(next_plan.get("type", ""))
	var special_name: String = str(next_plan.get("name", ""))

	if special_type == "" or special_name == "":
		return

	if customer.has_method("setup_special_customer"):
		customer.setup_special_customer(special_type, special_name)
		print("Applied special customer plan: ", special_type, " / ", special_name)

func prepare_stock_for_waiting_order(customer: Node, fulfillment_status: String) -> void:
	if customer == null or not is_instance_valid(customer):
		return

	var ingredients: Dictionary = customer.get_ingredients()
	var reserved_cooked: Dictionary = {}
	var remaining_to_cook: Dictionary = {}

	if fulfillment_status == "instant":
		deduct_cooked_stock(ingredients)

		customer.set_meta("reserved_cooked_ingredients", ingredients.duplicate(true))
		customer.set_meta("ingredients_to_cook", {})
		customer.set_meta("ingredients_deducted_at_checkout", true)

		RunSetupData.current_cooked_stock = cooked_stock.duplicate(true)
		return

	if fulfillment_status == "waitable":
		print("Preparing cart waiting order...")
		print("Before cooked stock: ", cooked_stock)
		print("Before raw stock: ", raw_stock)

		for ingredient_name in ingredients.keys():
			var item_key: String = str(ingredient_name)
			var needed_amount: int = int(ingredients.get(item_key, 0))

			if needed_amount <= 0:
				continue

			var available_cooked: int = int(cooked_stock.get(item_key, 0))
			if available_cooked < 0:
				available_cooked = 0

			var reserve_cooked_amount: int = needed_amount
			if available_cooked < reserve_cooked_amount:
				reserve_cooked_amount = available_cooked

			var missing_amount: int = needed_amount - reserve_cooked_amount
			if missing_amount < 0:
				missing_amount = 0

			if reserve_cooked_amount > 0:
				reserved_cooked[item_key] = reserve_cooked_amount
				cooked_stock[item_key] = available_cooked - reserve_cooked_amount

			if missing_amount > 0:
				remaining_to_cook[item_key] = missing_amount

		customer.set_meta("reserved_cooked_ingredients", reserved_cooked)
		customer.set_meta("ingredients_to_cook", remaining_to_cook)
		customer.set_meta("ingredients_deducted_at_checkout", true)

		RunSetupData.current_cooked_stock = cooked_stock.duplicate(true)

		print("Reserved cooked ingredients: ", reserved_cooked)
		print("Remaining ingredients to cook in cart pot: ", remaining_to_cook)
		print("After cooked stock: ", cooked_stock)
		print("Raw stock is NOT deducted at checkout in cart mode: ", raw_stock)
		return

	customer.set_meta("reserved_cooked_ingredients", {})
	customer.set_meta("ingredients_to_cook", ingredients.duplicate(true))
	customer.set_meta("ingredients_deducted_at_checkout", false)


func get_customer_ingredients_to_cook(customer: Node) -> Dictionary:
	if customer == null or not is_instance_valid(customer):
		return {}

	if customer.has_meta("ingredients_to_cook"):
		var value = customer.get_meta("ingredients_to_cook")
		if typeof(value) == TYPE_DICTIONARY:
			return value

	return {}

	customer.set_meta("reserved_cooked_ingredients", {})
	customer.set_meta("ingredients_to_cook", {})
	customer.set_meta("ingredients_deducted_at_checkout", false)

func initialize_round_stocks() -> void:
	if RunSetupData.current_raw_stock.is_empty():
		RunSetupData.current_raw_stock = planned_raw_stock.duplicate(true)

	if RunSetupData.current_cooked_stock.is_empty():
		RunSetupData.current_cooked_stock = planned_cooked_stock.duplicate(true)

	if RunSetupData.current_staple_stock.is_empty():
		RunSetupData.current_staple_stock = planned_staple_stock.duplicate(true)

	raw_stock = RunSetupData.current_raw_stock.duplicate(true)
	cooked_stock = RunSetupData.current_cooked_stock.duplicate(true)
	staple_stock = RunSetupData.current_staple_stock.duplicate(true)

func get_cart_pot_ingredient_ids() -> Array:
	var ids: Array = RunSetupData.get_basic_ingredient_ids()

	if ids.is_empty():
		ids = [
			"spinach",
			"potato_slice",
			"tofu_puff"
		]

	return ids


func get_stock_total(stock: Dictionary) -> int:
	var total := 0

	for item_id in stock.keys():
		total += int(stock.get(item_id, 0))

	return total


func get_cart_pot_cooked_capacity_used() -> int:
	return get_stock_total(cooked_stock)


func get_cart_pot_cooking_capacity_used() -> int:
	return get_stock_total(cart_pot_cooking_batch)


func get_cart_pot_selection_total() -> int:
	return get_stock_total(cart_pot_selection)


func get_cart_pot_used_capacity() -> int:
	return get_cart_pot_cooked_capacity_used() + get_cart_pot_cooking_capacity_used()


func get_cart_pot_total_capacity_with_selection() -> int:
	return get_cart_pot_used_capacity() + get_cart_pot_selection_total()


func get_cart_pot_available_capacity_for_selection() -> int:
	return max(cart_pot_capacity - get_cart_pot_total_capacity_with_selection(), 0)


func can_add_to_cart_pot_selection(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false

	if cart_pot_is_cooking:
		return false

	var current_selected := int(cart_pot_selection.get(item_id, 0))
	var current_raw := int(raw_stock.get(item_id, 0))

	if current_selected + amount > current_raw:
		return false

	if get_cart_pot_total_capacity_with_selection() + amount > cart_pot_capacity:
		return false

	return true


func add_to_cart_pot_selection(item_id: String, amount: int = 1) -> void:
	if amount <= 0:
		return

	var actually_added := 0

	for i in range(amount):
		if not can_add_to_cart_pot_selection(item_id, 1):
			break

		cart_pot_selection[item_id] = int(cart_pot_selection.get(item_id, 0)) + 1
		actually_added += 1

	if actually_added > 0:
		refresh_cart_pot_panel()


func remove_from_cart_pot_selection(item_id: String, amount: int = 1) -> void:
	if amount <= 0:
		return

	var current_selected := int(cart_pot_selection.get(item_id, 0))
	current_selected = max(current_selected - amount, 0)

	if current_selected <= 0:
		cart_pot_selection.erase(item_id)
	else:
		cart_pot_selection[item_id] = current_selected

	refresh_cart_pot_panel()


func max_add_to_cart_pot_selection(item_id: String) -> void:
	if cart_pot_is_cooking:
		return

	var current_selected: int = int(cart_pot_selection.get(item_id, 0))
	var current_raw: int = int(raw_stock.get(item_id, 0))

	var raw_room: int = current_raw - current_selected
	if raw_room < 0:
		raw_room = 0

	var capacity_room: int = get_cart_pot_available_capacity_for_selection()

	var amount: int = raw_room
	if capacity_room < amount:
		amount = capacity_room

	if amount <= 0:
		return

	add_to_cart_pot_selection(item_id, amount)


func start_cart_pot_batch_cooking() -> void:
	if cart_pot_is_cooking:
		print("大锅已经在煮了。")
		return

	if cart_pot_selection.is_empty():
		print("没有选择要煮的配菜。")
		return

	var batch: Dictionary = {}

	for item_id in cart_pot_selection.keys():
		var item_key: String = str(item_id)
		var amount: int = int(cart_pot_selection.get(item_key, 0))

		if amount <= 0:
			continue

		var raw_amount: int = int(raw_stock.get(item_key, 0))

		if raw_amount <= 0:
			continue

		var actual_amount: int = min(amount, raw_amount)

		if actual_amount <= 0:
			continue

		batch[item_key] = actual_amount

	if batch.is_empty():
		print("本次选择没有可煮的配菜。")
		cart_pot_selection.clear()
		refresh_cart_pot_panel()
		return

	if get_cart_pot_total_capacity_with_selection() > cart_pot_capacity:
		print("大锅容量不足，不能开始煮。")
		refresh_cart_pot_panel()
		return

	for item_id in batch.keys():
		var item_key: String = str(item_id)
		var amount: int = int(batch.get(item_key, 0))
		raw_stock[item_key] = int(raw_stock.get(item_key, 0)) - amount

	cart_pot_is_cooking = true
	cart_pot_cooking_batch = batch.duplicate(true)
	cart_pot_time_left = get_effective_cart_pot_batch_duration()
	cart_pot_selection.clear()

	RunSetupData.current_raw_stock = raw_stock.duplicate(true)

	print("=== 大锅开始批量烹饪 ===")
	print("Batch: ", cart_pot_cooking_batch)
	print("大锅本次烹饪时间：", cart_pot_time_left)
	print("Raw stock after starting cart pot: ", raw_stock)
	print("Cart pot capacity used: %d/%d" % [
		get_cart_pot_total_capacity_with_selection(),
		cart_pot_capacity
	])

	refresh_cart_pot_panel()


func update_cart_pot(delta: float) -> void:
	if not cart_pot_is_cooking:
		return

	cart_pot_time_left -= delta

	if cart_pot_time_left > 0.0:
		if cart_pot_layer != null and is_instance_valid(cart_pot_layer):
			refresh_cart_pot_panel()
		return

	finish_cart_pot_batch_cooking()


func finish_cart_pot_batch_cooking() -> void:
	if not cart_pot_is_cooking:
		return

	for item_id in cart_pot_cooking_batch.keys():
		var item_key := str(item_id)
		var amount := int(cart_pot_cooking_batch.get(item_key, 0))

		if amount <= 0:
			continue

		if not cooked_stock.has(item_key):
			cooked_stock[item_key] = 0

		cooked_stock[item_key] = int(cooked_stock.get(item_key, 0)) + amount

	print("=== 大锅批量烹饪完成 ===")
	print("Cooked batch: ", cart_pot_cooking_batch)

	cart_pot_is_cooking = false
	cart_pot_time_left = 0.0
	cart_pot_cooking_batch.clear()

	RunSetupData.current_cooked_stock = cooked_stock.duplicate(true)

	print("Cooked stock after cart pot: ", cooked_stock)
	print("Cart pot capacity used: ", get_cart_pot_used_capacity(), "/", cart_pot_capacity)

	refresh_cart_pot_panel()
	print_stocks()

func initialize_staple_ladle_slots() -> void:
	staple_ladle_slots.clear()

	for i in range(2):
		staple_ladle_slots.append({
			"state": "empty",
			"main_food_id": "",
			"time_left": 0.0
		})

	held_raw_staple_food_id = ""
	held_staple_food_id = ""


func has_busy_staple_ladle() -> bool:
	for i in range(staple_ladle_slots.size()):
		var slot: Dictionary = staple_ladle_slots[i] as Dictionary
		var state: String = str(slot.get("state", "empty"))

		if state == "cooking":
			return true

	return false


func update_staple_ladle_slots(delta: float) -> void:
	if staple_ladle_slots.is_empty():
		return

	var changed := false

	for i in range(staple_ladle_slots.size()):
		var slot: Dictionary = staple_ladle_slots[i] as Dictionary
		var state: String = str(slot.get("state", "empty"))

		if state != "cooking":
			continue

		var time_left: float = float(slot.get("time_left", 0.0))
		time_left -= delta

		if time_left <= 0.0:
			slot["state"] = "ready"
			slot["time_left"] = 0.0
			print("漏勺 ", i + 1, " 的 ", get_ingredient_display_name(str(slot.get("main_food_id", ""))), " 煮好了。")
		else:
			slot["time_left"] = time_left

		staple_ladle_slots[i] = slot
		changed = true

	if changed and cart_pot_layer != null and is_instance_valid(cart_pot_layer):
		refresh_cart_pot_panel()


func get_first_pending_customer_waiting_for_main_food(main_food_id: String) -> Node:
	for customer in pending_customers:
		if customer == null or not is_instance_valid(customer):
			continue

		if bool(customer.get("order_served")):
			continue

		if bool(customer.get("needs_emergency_purchase")):
			continue

		if not customer_has_main_food(customer):
			continue

		if get_customer_main_food_stock_id(customer) != main_food_id:
			continue

		if not bool(customer.get("needs_main_food_cooking")):
			continue

		return customer

	return null


func has_waiting_main_food_order(main_food_id: String) -> bool:
	return get_unassigned_waiting_main_food_count(main_food_id) > 0

func get_waiting_main_food_count(main_food_id: String) -> int:
	var count := 0

	for customer in pending_customers:
		if customer == null or not is_instance_valid(customer):
			continue

		if bool(customer.get("order_served")):
			continue

		if bool(customer.get("needs_emergency_purchase")):
			continue

		if not customer_has_main_food(customer):
			continue

		if get_customer_main_food_stock_id(customer) != main_food_id:
			continue

		if not bool(customer.get("needs_main_food_cooking")):
			continue

		count += 1

	return count

func get_assigned_staple_food_count(main_food_id: String) -> int:
	var count: int = 0

	for i in range(staple_ladle_slots.size()):
		var slot: Dictionary = staple_ladle_slots[i] as Dictionary
		var state: String = str(slot.get("state", "empty"))
		var slot_food_id: String = str(slot.get("main_food_id", ""))

		if state == "empty":
			continue

		if slot_food_id == main_food_id:
			count += 1

	if held_staple_food_id == main_food_id:
		count += 1

	return count


func get_unassigned_waiting_main_food_count(main_food_id: String) -> int:
	var waiting_count: int = get_waiting_main_food_count(main_food_id)
	var assigned_count: int = get_assigned_staple_food_count(main_food_id)

	var available_count: int = waiting_count - assigned_count
	if available_count < 0:
		available_count = 0

	return available_count

func can_start_staple_ladle_cooking(slot_index: int, main_food_id: String) -> bool:
	if slot_index < 0 or slot_index >= staple_ladle_slots.size():
		return false

	if main_food_id == "":
		return false

	if not RunSetupData.is_staple_item(main_food_id):
		return false

	var slot: Dictionary = staple_ladle_slots[slot_index] as Dictionary
	var state: String = str(slot.get("state", "empty"))

	if state != "empty":
		return false

	var current_stock: int = int(staple_stock.get(main_food_id, 0))

	if current_stock <= 0:
		return false

	return true

func start_staple_ladle_cooking(slot_index: int, main_food_id: String) -> void:
	if not can_start_staple_ladle_cooking(slot_index, main_food_id):
		print("不能开始煮主食：", main_food_id, " slot=", slot_index)
		return

	var slot: Dictionary = staple_ladle_slots[slot_index] as Dictionary

	slot["state"] = "cooking"
	slot["main_food_id"] = main_food_id
	slot["time_left"] = get_effective_staple_ladle_duration()
	slot["is_ready"] = false
	staple_ladle_slots[slot_index] = slot

	staple_stock[main_food_id] = int(staple_stock.get(main_food_id, 0)) - 1
	RunSetupData.current_staple_stock = staple_stock.duplicate(true)

	print("漏勺 ", slot_index + 1, " 开始煮：", get_ingredient_display_name(main_food_id))
	print("漏勺本次烹饪时间：", slot["time_left"])
	print("Staple stock after putting into ladle: ", staple_stock)

	request_cart_pot_panel_refresh()


func take_ready_staple_from_ladle(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= staple_ladle_slots.size():
		return

	if held_staple_food_id != "":
		print("手里已经有主食：", get_ingredient_display_name(held_staple_food_id), "。先去出餐点交付。")
		return

	var slot: Dictionary = staple_ladle_slots[slot_index] as Dictionary
	var state: String = str(slot.get("state", "empty"))

	if state != "ready":
		print("漏勺 ", slot_index + 1, " 还没有可以取出的主食。")
		return

	var main_food_id: String = str(slot.get("main_food_id", ""))

	if main_food_id == "":
		return

	held_staple_food_id = main_food_id

	slot["state"] = "empty"
	slot["main_food_id"] = ""
	slot["time_left"] = 0.0
	staple_ladle_slots[slot_index] = slot

	print("从漏勺 ", slot_index + 1, " 取出：", get_ingredient_display_name(main_food_id), "。现在手里拿着这份主食。")

	refresh_cart_pot_panel()

func interact_with_staple_basket(main_food_id: String) -> void:
	if main_food_id == "":
		print("没有指定主食筐。")
		return

	if not RunSetupData.is_staple_item(main_food_id):
		print("这不是可用主食：", main_food_id)
		return

	var display_name: String = get_ingredient_display_name(main_food_id)

	if held_staple_food_id != "":
		print("手里已经拿着熟主食：", get_ingredient_display_name(held_staple_food_id), "。先去出餐点交付。")
		return

	if held_raw_staple_food_id == "":
		var current_stock: int = int(staple_stock.get(main_food_id, 0))

		if current_stock <= 0:
			print(display_name, " 库存不足，不能拿起。")
			return

		held_raw_staple_food_id = main_food_id
		print("拿起生主食：", display_name, "。此时不扣库存。")
		print("当前主食库存：", staple_stock)
		return

	if held_raw_staple_food_id == main_food_id:
		print("把生主食放回：", display_name, "。因为还没下漏勺，所以不扣库存。")
		held_raw_staple_food_id = ""
		return

	print("手里拿着的是：", get_ingredient_display_name(held_raw_staple_food_id), "。要回对应主食筐才能放回。")


func interact_with_staple_ladle(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= staple_ladle_slots.size():
		print("漏勺编号不存在：", slot_index)
		return

	var slot: Dictionary = staple_ladle_slots[slot_index] as Dictionary
	var state: String = str(slot.get("state", "empty"))

	if state == "empty":
		if held_raw_staple_food_id == "":
			print("漏勺 ", slot_index + 1, " 是空的。先去粉丝筐或面筐拿生主食。")
			return

		if held_staple_food_id != "":
			print("手里已经拿着熟主食：", get_ingredient_display_name(held_staple_food_id), "。先去出餐点交付。")
			return

		var main_food_id: String = held_raw_staple_food_id

		if not can_start_staple_ladle_cooking(slot_index, main_food_id):
			print("不能把 ", get_ingredient_display_name(main_food_id), " 放入漏勺 ", slot_index + 1, "。")
			return

		start_staple_ladle_cooking(slot_index, main_food_id)
		held_raw_staple_food_id = ""
		print("已经把生主食放入漏勺 ", slot_index + 1, "。这时才扣库存。")
		return

	if state == "cooking":
		var cooking_food_id: String = str(slot.get("main_food_id", ""))
		var time_left: float = float(slot.get("time_left", 0.0))
		print("漏勺 ", slot_index + 1, " 正在煮 ", get_ingredient_display_name(cooking_food_id), "，还剩 %.1f 秒。" % time_left)
		return

	if state == "ready":
		if held_raw_staple_food_id != "":
			print("手里还拿着生主食：", get_ingredient_display_name(held_raw_staple_food_id), "。先放回主食筐，或者找空漏勺下锅。")
			return

		take_ready_staple_from_ladle(slot_index)
		return

	print("漏勺 ", slot_index + 1, " 状态异常：", state)


func get_held_raw_staple_text() -> String:
	if held_raw_staple_food_id == "":
		return "空"
	return get_ingredient_display_name(held_raw_staple_food_id)

func get_held_staple_text() -> String:
	if held_staple_food_id == "":
		return "空"

	return get_ingredient_display_name(held_staple_food_id)


func get_staple_ladle_text(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= staple_ladle_slots.size():
		return "漏勺不存在"

	var slot: Dictionary = staple_ladle_slots[slot_index] as Dictionary
	var state: String = str(slot.get("state", "empty"))
	var main_food_id: String = str(slot.get("main_food_id", ""))
	var main_food_text := "无"

	if main_food_id != "":
		main_food_text = get_ingredient_display_name(main_food_id)

	if state == "empty":
		return "漏勺 %d：空" % [slot_index + 1]

	if state == "cooking":
		return "漏勺 %d：正在煮 %s，剩余 %.1f 秒" % [
			slot_index + 1,
			main_food_text,
			float(slot.get("time_left", 0.0))
		]

	if state == "ready":
		return "漏勺 %d：%s 已煮好，等待取出" % [
			slot_index + 1,
			main_food_text
		]

	return "漏勺 %d：未知状态" % [slot_index + 1]

func initialize_cooker_slots() -> void:
	cooker_slots.clear()
	for i in range(total_cooker_slots):
		cooker_slots.append({
			"is_busy": false,
			"customer": null,
			"time_left": 0.0
		})

func apply_station_layout_from_run_setup() -> void:
	var layout: Dictionary = RunSetupData.station_layout

	place_station_by_slot(counter_node, str(layout.get("counter", "")))
	place_station_by_slot(delivery_node, str(layout.get("delivery", "")))
	place_station_by_slot(storage_node, str(layout.get("storage", "")))
	place_station_by_slot(cooker_1_node, str(layout.get("cooker_1", "")))
	place_station_by_slot(emergency_shop_node, str(layout.get("emergency_shop", "")))

	if cooker_2_node != null:
		if has_second_cooker:
			cooker_2_node.visible = true
			place_station_by_slot(cooker_2_node, str(layout.get("cooker_2", "")))
		else:
			cooker_2_node.visible = false

func place_station_by_slot(station_node: Node2D, slot_id: String) -> void:
	if station_node == null:
		return

	var slot_marker := get_slot_marker_by_id(slot_id)
	if slot_marker == null:
		print("No valid slot found for station: ", station_node.name, " slot_id: ", slot_id)
		return

	station_node.global_position = slot_marker.global_position
	print("Placed station ", station_node.name, " at ", slot_id, " -> ", slot_marker.global_position)

func get_slot_marker_by_id(slot_id: String) -> Marker2D:
	match slot_id:
		"slot_a":
			return slot_a
		"slot_b":
			return slot_b
		"slot_c":
			return slot_c
		"slot_d":
			return slot_d
		"slot_e":
			return slot_e
		"slot_f":
			return slot_f
		_:
			return null

func update_cooker_slots(delta: float) -> void:
	for i in range(cooker_slots.size()):
		var slot = cooker_slots[i]

		if not slot["is_busy"]:
			continue

		slot["time_left"] -= delta

		if slot["time_left"] > 0.0:
			cooker_slots[i] = slot
			continue

		var customer = slot["customer"]
		if customer != null and is_instance_valid(customer):
			customer.mark_food_ready()
			print("Cooking finished in slot ", i, ". Order is ready for delivery.")
			print("This cooked food belongs to this customer and is not added to public cooked_stock.")
			print_stocks()

		slot["is_busy"] = false
		slot["customer"] = null
		slot["time_left"] = 0.0
		cooker_slots[i] = slot

func get_queue_positions() -> Array:
	return [
		queue_spot_1.global_position,
		queue_spot_2.global_position,
		queue_spot_3.global_position
	]

func refresh_queue_positions() -> void:
	var queue_positions = get_queue_positions()

	for i in range(queued_customers.size()):
		var customer = queued_customers[i]
		if customer != null and is_instance_valid(customer) and customer.is_in_queue:
			if i < queue_positions.size():
				customer.move_to_queue_position(queue_positions[i], i)

func open_business() -> void:
	if is_open_for_business:
		return

	if is_round_closing or has_round_finished:
		print("Round is closing or already finished. Cannot open business again.")
		return

	has_opened_for_business_today = true
	close_supplier_order_panel()

	is_open_for_business = true

	print("=== 开始营业 ===")

	start_initial_customer_wave()

func close_business() -> void:
	if not is_open_for_business:
		return

	is_open_for_business = false
	is_round_closing = true

	if spawn_timer != null and is_instance_valid(spawn_timer):
		spawn_timer.stop()

	print("=== 已打烊 ===")
	try_finish_day()

func can_spawn_customers_now() -> bool:
	return is_open_for_business

func start_initial_customer_wave() -> void:
	if not can_spawn_customers_now():
		return

	print("start spawning customers after opening...")
	for i in range(max_queue_size):
		if queued_customers.size() >= max_queue_size:
			break
		print("spawn attempt after opening: ", i)
		spawn_customer()

func spawn_customer() -> void:
	if not can_spawn_customers_now():
		print("当前状态不允许刷客。")
		return

	if customer_scene == null:
		print("Customer scene is missing")
		return

	if queued_customers.size() >= max_queue_size:
		print("Queue already full")
		return

	var customer_instance = customer_scene.instantiate()
	print("spawned customer instance: ", customer_instance)

	characters_node.add_child(customer_instance)
	customer_instance.global_position = customer_spawn.global_position
	print("customer initial pos: ", customer_instance.global_position)

	_apply_special_customer_plan_to_customer(customer_instance)

	queued_customers.append(customer_instance)
	refresh_queue_positions()

	customer_instance.tree_exited.connect(_on_customer_exited.bind(customer_instance))



func record_special_customer_result(customer: Node, result: String) -> void:
	if customer == null or not is_instance_valid(customer):
		return

	if not bool(customer.get("is_special_customer")):
		return

	if bool(customer.get("special_result_recorded")):
		return

	var special_type: String = str(customer.get("special_customer_type"))
	var special_name: String = str(customer.get("special_customer_name"))

	var gift_data := RunSetupData.add_pending_gift(
		special_type,
		special_name,
		result
	)

	var result_data := {
		"type": special_type,
		"name": special_name,
		"result": result,
		"gift_id": str(gift_data.get("gift_id", ""))
	}

	RunSetupData.today_special_customer_results.append(result_data)

	customer.set("special_result_recorded", true)

	print("Recorded special customer result: ", result_data)
	print("Special customer left an echo: ", gift_data)

func handle_customer_order_completed(customer: Node) -> void:
	if customer == null or not is_instance_valid(customer):
		return

	RunSetupData.record_today_served_customer()

	var delta := get_reputation_delta_for_customer(customer, "served")
	change_shop_reputation(delta, "%s served" % get_customer_group(customer))
	record_special_customer_result(customer, "good")

func handle_customer_patience_timeout(customer: Node) -> void:
	if customer == null or not is_instance_valid(customer):
		return

	RunSetupData.record_today_failed_customer()

	var delta := get_reputation_delta_for_customer(customer, "failed")
	change_shop_reputation(delta, "%s patience timeout" % get_customer_group(customer))
	record_special_customer_result(customer, "bad")

func get_counter_customer() -> Node:
	while not queued_customers.is_empty():
		var customer = queued_customers[0]
		if customer != null and is_instance_valid(customer):
			return customer
		queued_customers.remove_at(0)

	return null

func begin_checkout_for_customer(customer: Node) -> bool:
	if customer == null or not is_instance_valid(customer):
		return false

	if customer.is_checked_out:
		print("This customer has already checked out.")
		return false

	customer.order_revealed = true
	if customer.has_method("mark_checkout_started"):
		customer.mark_checkout_started()

	var game_ui = get_tree().get_first_node_in_group("game_ui")
	if game_ui:
		game_ui.show_order(
			customer.get_order_name(),
			customer.get_main_food(),
			customer.get_ingredients_text()
		)

	print("Customer order revealed: ", customer.get_order_name())
	print("Main food: ", customer.get_main_food())
	print("Ingredients: ", customer.get_ingredients_text())
	return true

func evaluate_order_before_checkout(customer: Node) -> Dictionary:
	var result := {
		"status": "invalid",
		"needs_waiting": false,
		"needs_main_food_cooking": false,
		"needs_ingredient_cooking": false,
		"needs_emergency_purchase": false,
		"fulfillment_status": "invalid",
		"shortage": {}
	}

	if customer == null or not is_instance_valid(customer):
		return result

	var ingredients: Dictionary = customer.get_ingredients()
	var fulfillment_status: String = get_order_fulfillment_status(ingredients)
	var has_main_food: bool = customer.get_main_food_id() != "none"

	var needs_main_food_cooking: bool = has_main_food
	var needs_ingredient_cooking: bool = fulfillment_status != "instant"
	var needs_emergency_purchase: bool = fulfillment_status == "unfulfillable"
	var needs_waiting: bool = needs_main_food_cooking or needs_ingredient_cooking or needs_emergency_purchase

	result["status"] = "ok"
	result["needs_waiting"] = needs_waiting
	result["needs_main_food_cooking"] = needs_main_food_cooking
	result["needs_ingredient_cooking"] = needs_ingredient_cooking
	result["needs_emergency_purchase"] = needs_emergency_purchase
	result["fulfillment_status"] = fulfillment_status
	result["shortage"] = get_order_shortage(ingredients)

	return result

func customer_can_checkout_now(customer: Node) -> bool:
	if customer == null or not is_instance_valid(customer):
		return false
	return not customer.is_checked_out

func get_counter_customer_stock_preview(customer: Node) -> Dictionary:
	if customer == null or not is_instance_valid(customer):
		return {}

	return {
		"cooked_text": get_cooked_stock_text(),
		"raw_text": get_raw_stock_text(),
		"shortage": get_order_shortage(customer.get_ingredients()),
		"adjusted_order": get_adjusted_order(customer.get_ingredients())
	}

func confirm_checkout_and_create_order(customer: Node, quoted_price: int = -1) -> Dictionary:
	var result := {
		"success": false,
		"price_reaction": "accept",
		"final_price": 0,
		"route": "none",
		"message": ""
	}

	if customer == null or not is_instance_valid(customer):
		result["message"] = "Invalid customer."
		return result

	if customer.is_checked_out:
		result["message"] = "Customer already checked out."
		return result

	var evaluation := evaluate_order_before_checkout(customer)
	if evaluation["status"] != "ok":
		result["message"] = "Order evaluation failed."
		return result

	var true_price: int = customer.get_order_price()
	var final_price: int = true_price if quoted_price < 0 else quoted_price

	var price_reaction: String = resolve_price_reaction(customer, final_price, true_price)
	result["price_reaction"] = price_reaction
	result["final_price"] = final_price

	if price_reaction != "accept":
		result["message"] = "Customer did not accept the quoted price yet."
		return result

	if customer.has_method("mark_payment_completed"):
		customer.mark_payment_completed(final_price, true_price)
	else:
		customer.is_checked_out = true
		customer.paid_price = final_price

	add_money(final_price)

	var game_ui = get_tree().get_first_node_in_group("game_ui")
	if game_ui:
		game_ui.hide_order()

	var route_result := route_customer_after_payment(customer, evaluation)
	result["success"] = true
	result["route"] = route_result
	result["message"] = "Checkout completed."

	return result

func route_customer_after_payment(customer: Node, evaluation: Dictionary) -> String:
	var fulfillment_status: String = str(evaluation.get("fulfillment_status", "invalid"))
	var needs_waiting: bool = bool(evaluation.get("needs_waiting", false))
	var needs_main_food_cooking: bool = bool(evaluation.get("needs_main_food_cooking", false))
	var needs_ingredient_cooking: bool = bool(evaluation.get("needs_ingredient_cooking", false))
	var needs_emergency_purchase: bool = bool(evaluation.get("needs_emergency_purchase", false))

	if needs_emergency_purchase:
		customer.needs_main_food_cooking = needs_main_food_cooking
		customer.needs_ingredient_cooking = true
		customer.needs_emergency_purchase = true

		customer.set_meta("reserved_cooked_ingredients", {})
		customer.set_meta("ingredients_to_cook", customer.get_ingredients().duplicate(true))
		customer.set_meta("ingredients_deducted_at_checkout", false)

		customer.start_waiting_for_food(needs_main_food_cooking, true)

		var emergency_delivery_spot: Node = get_tree().get_first_node_in_group("delivery_spot") as Node
		if emergency_delivery_spot:
			customer.go_to_delivery(emergency_delivery_spot.global_position)
		else:
			print("No delivery spot found.")

		pending_customers.append(customer)
		release_counter_customer(customer)

		print("Customer paid, but order currently needs emergency purchase.")
		return "waiting_emergency"

	if fulfillment_status == "instant":
		prepare_stock_for_waiting_order(customer, fulfillment_status)

		if not needs_waiting:
			customer.mark_order_served()

			if has_method("handle_customer_order_completed"):
				handle_customer_order_completed(customer)

			var instant_exit_point: Node = get_tree().get_first_node_in_group("exit_point") as Node
			if instant_exit_point:
				customer.go_to_exit(instant_exit_point.global_position)

			release_counter_customer(customer)

			print("Customer paid and took food immediately.")
			return "instant_leave"

		customer.needs_main_food_cooking = needs_main_food_cooking
		customer.needs_ingredient_cooking = false
		customer.needs_emergency_purchase = false

		customer.start_waiting_for_food(needs_main_food_cooking, false)

		var instant_delivery_spot: Node = get_tree().get_first_node_in_group("delivery_spot") as Node
		if instant_delivery_spot:
			customer.go_to_delivery(instant_delivery_spot.global_position)
		else:
			print("No delivery spot found.")

		pending_customers.append(customer)
		release_counter_customer(customer)

		print("Customer paid and is now waiting for main food.")
		return "waiting_delivery"

	if fulfillment_status == "waitable":
		prepare_stock_for_waiting_order(customer, fulfillment_status)

		var ingredients_to_cook: Dictionary = get_customer_ingredients_to_cook(customer)
		var still_needs_ingredients: bool = not ingredients_to_cook.is_empty()

		customer.needs_main_food_cooking = needs_main_food_cooking
		customer.needs_ingredient_cooking = still_needs_ingredients
		customer.needs_emergency_purchase = false

		customer.start_waiting_for_food(needs_main_food_cooking, still_needs_ingredients)

		if not still_needs_ingredients and customer.has_method("mark_cart_ingredients_ready"):
			customer.mark_cart_ingredients_ready()

		var waitable_delivery_spot: Node = get_tree().get_first_node_in_group("delivery_spot") as Node
		if waitable_delivery_spot:
			customer.go_to_delivery(waitable_delivery_spot.global_position)
		else:
			print("No delivery spot found.")

		pending_customers.append(customer)
		release_counter_customer(customer)

		print("Customer paid and is now waiting for food.")
		return "waiting_delivery"

	customer.needs_main_food_cooking = needs_main_food_cooking
	customer.needs_ingredient_cooking = true
	customer.needs_emergency_purchase = true

	customer.set_meta("reserved_cooked_ingredients", {})
	customer.set_meta("ingredients_to_cook", customer.get_ingredients().duplicate(true))
	customer.set_meta("ingredients_deducted_at_checkout", false)

	customer.start_waiting_for_food(needs_main_food_cooking, true)

	var fallback_delivery_spot: Node = get_tree().get_first_node_in_group("delivery_spot") as Node
	if fallback_delivery_spot:
		customer.go_to_delivery(fallback_delivery_spot.global_position)
	else:
		print("No delivery spot found.")

	pending_customers.append(customer)
	release_counter_customer(customer)

	print("Customer paid, but order currently needs emergency purchase.")
	return "waiting_emergency"

func refresh_money_and_reputation_ui() -> void:
	var game_ui = get_tree().get_first_node_in_group("game_ui")
	if game_ui:
		game_ui.update_money(money)

func change_shop_reputation(delta: int, reason: String = "") -> void:
	var old_value: int = RunSetupData.shop_reputation
	RunSetupData.shop_reputation = clamp(RunSetupData.shop_reputation + delta, 0, 100)

	var actual_delta: int = RunSetupData.shop_reputation - old_value
	RunSetupData.today_reputation_delta += actual_delta

	print("Reputation changed: ", old_value, " -> ", RunSetupData.shop_reputation, " | delta: ", actual_delta, " | reason: ", reason)

	refresh_money_and_reputation_ui()

func is_pending_customer_fully_submitted(customer: Node) -> bool:
	if customer == null or not is_instance_valid(customer):
		return false

	if customer.order_served:
		return false

	var remaining_main_food_text: String = get_pending_order_remaining_main_food_text(customer)
	var remaining_ingredients: Dictionary = get_pending_order_remaining_ingredients(customer)

	return remaining_main_food_text == "" and remaining_ingredients.is_empty()

func interact_with_delivery_point() -> void:
	var changed_anything: bool = false
	var completed_customer: Node = null

	if held_staple_food_id != "":
		var staple_customer: Node = hand_over_held_staple_to_waiting_customer()

		if staple_customer == null:
			print("没有等待这个主食的顾客。")
			return

		changed_anything = true

		if staple_customer.can_be_delivered() or is_pending_customer_fully_submitted(staple_customer):
			completed_customer = staple_customer

		if completed_customer != null:
			complete_delivery_for_customer(completed_customer)
			return

		print("已提交主食。订单还没完成，订单卡会继续显示剩余内容。")

		if cart_pot_layer != null and is_instance_valid(cart_pot_layer):
			refresh_cart_pot_panel()

		return

	for customer in pending_customers:
		if customer == null or not is_instance_valid(customer):
			continue

		if customer.order_served:
			continue

		if customer.can_be_delivered() or is_pending_customer_fully_submitted(customer):
			completed_customer = customer
			break

		if try_fulfill_cart_ingredients_for_customer(customer):
			changed_anything = true

			if customer.can_be_delivered() or is_pending_customer_fully_submitted(customer):
				completed_customer = customer

			break

	if completed_customer != null:
		complete_delivery_for_customer(completed_customer)
		return

	if changed_anything:
		print("已提交当前能交的配菜。订单还没完成，订单卡会继续显示剩余内容。")

		if cart_pot_layer != null and is_instance_valid(cart_pot_layer):
			refresh_cart_pot_panel()

		return

	print("No deliverable customer.")

func complete_delivery_for_customer(customer: Node) -> bool:
	if customer == null or not is_instance_valid(customer):
		print("Cannot deliver: invalid customer.")
		return false

	var can_complete: bool = customer.can_be_delivered() or is_pending_customer_fully_submitted(customer)

	if not can_complete:
		print("Cannot deliver: customer order is not ready.")
		return false

	customer.needs_emergency_purchase = false
	customer.needs_main_food_cooking = false
	customer.needs_ingredient_cooking = false
	customer.cart_main_food_ready = true
	customer.cart_ingredients_ready = true

	customer.mark_order_served()

	if has_method("handle_customer_order_completed"):
		handle_customer_order_completed(customer)

	remove_customer_from_pending(customer)

	var exit_point = get_tree().get_first_node_in_group("exit_point")
	if exit_point:
		customer.go_to_exit(exit_point.global_position)

	print("Delivered order to customer.")

	if cart_pot_layer != null and is_instance_valid(cart_pot_layer):
		refresh_cart_pot_panel()

	return true

func build_night_queue_from_today_results() -> Array:
	var queue: Array = [
		{
			"type": "insight",
			"name": "小猫领悟",
			"result": "neutral"
		}
	]

	for entry in RunSetupData.today_special_customer_results:
		var gift_id := str(entry.get("gift_id", ""))

		if gift_id != "" and RunSetupData.is_gift_opened(gift_id):
			print("Skip opened special echo at night: ", gift_id)
			continue

		var result_text: String = str(entry.get("result", "neutral"))
		var entry_name: String = str(entry.get("name", "特殊客人"))

		if result_text == "good":
			queue.append({
				"type": "good",
				"name": entry_name,
				"result": "good",
				"gift_id": gift_id
			})
		elif result_text == "bad":
			queue.append({
				"type": "bad",
				"name": entry_name,
				"result": "bad",
				"gift_id": gift_id
			})

	return queue

func handle_stock_shortage_for_customer(customer: Node) -> Dictionary:
	var result := {
		"has_alternative": false,
		"adjusted_order": {},
		"should_leave": false
	}

	if customer == null or not is_instance_valid(customer):
		result["should_leave"] = true
		return result

	var adjusted_order: Dictionary = get_adjusted_order(customer.get_ingredients())
	if adjusted_order.size() > 0:
		result["has_alternative"] = true
		result["adjusted_order"] = adjusted_order
	else:
		result["should_leave"] = true

	return result

func apply_adjusted_order_to_customer(customer: Node, adjusted_order: Dictionary) -> void:
	if customer == null or not is_instance_valid(customer):
		return

	customer.set_ingredients(adjusted_order)
	customer.order_revealed = true

	if customer.has_method("mark_back_to_counter_waiting"):
		customer.mark_back_to_counter_waiting()

	var game_ui = get_tree().get_first_node_in_group("game_ui")
	if game_ui:
		game_ui.show_order(
			customer.get_order_name(),
			customer.get_main_food(),
			customer.get_ingredients_text()
		)

	print("Customer accepts adjusted order: ", customer.get_ingredients_text())

func reject_customer_before_checkout(customer: Node) -> void:
	if customer == null or not is_instance_valid(customer):
		return

	RunSetupData.record_today_failed_customer()

	var delta := get_reputation_delta_for_customer(customer, "failed")
	change_shop_reputation(delta, "%s rejected before checkout" % get_customer_group(customer))
	record_special_customer_result(customer, "bad")

	var exit_point = get_tree().get_first_node_in_group("exit_point")

	if exit_point:
		customer.go_to_exit(exit_point.global_position)

	release_counter_customer(customer)

	print("Customer leaves before checkout.")

func get_customer_group(customer: Node) -> String:
	if customer == null or not is_instance_valid(customer):
		return "invalid"

	if customer.has_method("get_customer_group"):
		return customer.get_customer_group()

	if bool(customer.get("is_special_customer")):
		return "special"

	return "normal"

func get_customer_type(customer: Node) -> String:
	if customer == null or not is_instance_valid(customer):
		return "invalid"

	if customer.has_method("get_customer_type"):
		return customer.get_customer_type()

	if bool(customer.get("is_special_customer")):
		return str(customer.get("special_customer_type"))

	return "normal_default"

func get_reputation_delta_for_customer(customer: Node, event_name: String) -> int:
	var group := get_customer_group(customer)
	var customer_type := get_customer_type(customer)

	if event_name == "served":
		if group == "special":
			return 3

		return 1

	if event_name == "failed":
		if group == "special":
			return -5

		return -2

	print("Unknown reputation event: ", event_name, " | group: ", group, " | type: ", customer_type)
	return 0

func resolve_price_reaction(_customer: Node, _quoted_price: int, _true_price: int) -> String:
	# 先留接口：以后在这里接“多收费 / 少收费 / 顾客性格 / 卡牌Buff”
	return "accept"

func get_first_customer_needing_emergency_purchase() -> Node:
	var total_shortage: Dictionary = get_total_pending_emergency_shortage()

	if total_shortage.is_empty():
		refresh_all_pending_emergency_purchase_states()
		return null

	print("Emergency total shortage: ", total_shortage)

	for customer in pending_customers:
		if customer == null or not is_instance_valid(customer):
			continue

		if customer.order_served:
			continue

		customer.needs_emergency_purchase = true
		return customer

	return null

func get_first_uncooked_pending_customer() -> Node:
	for customer in pending_customers:
		if customer != null and is_instance_valid(customer):
			if customer.needs_emergency_purchase:
				continue
			if customer.can_be_delivered():
				continue
			if is_customer_in_any_cooker(customer):
				continue
			return customer
	return null

func get_cart_ingredients_needed_from_pot(customer: Node) -> Dictionary:
	if customer == null or not is_instance_valid(customer):
		return {}

	if customer.has_meta("ingredients_to_cook"):
		var ingredients_to_cook = customer.get_meta("ingredients_to_cook")

		if typeof(ingredients_to_cook) == TYPE_DICTIONARY:
			return ingredients_to_cook

	if customer.has_meta("ingredients_deducted_at_checkout"):
		var already_deducted: bool = bool(customer.get_meta("ingredients_deducted_at_checkout"))

		if already_deducted:
			return {}

	if customer.has_method("get_ingredients"):
		return customer.get_ingredients()

	return {}

func get_cart_ingredient_shortage_for_customer(customer: Node) -> Dictionary:
	var shortage: Dictionary = {}

	if customer == null or not is_instance_valid(customer):
		return shortage

	if bool(customer.get("order_served")):
		return shortage

	if not bool(customer.get("needs_ingredient_cooking")):
		return shortage

	if bool(customer.get("cart_ingredients_ready")):
		return shortage

	var needed_ingredients: Dictionary = get_cart_ingredients_needed_from_pot(customer)

	if needed_ingredients.is_empty():
		return shortage

	for item_id in needed_ingredients.keys():
		var item_key: String = str(item_id)
		var needed_amount: int = int(needed_ingredients.get(item_key, 0))

		if needed_amount <= 0:
			continue

		var cooked_amount: int = int(cooked_stock.get(item_key, 0))
		var raw_amount: int = int(raw_stock.get(item_key, 0))
		var available_amount: int = cooked_amount + raw_amount
		var missing_amount: int = needed_amount - available_amount

		if missing_amount > 0:
			shortage[item_key] = missing_amount

	return shortage


func try_fulfill_cart_ingredients_for_customer(customer: Node) -> bool:
	if customer == null or not is_instance_valid(customer):
		return false

	if customer.order_served:
		return false

	var remaining_ingredients: Dictionary = get_pending_order_remaining_ingredients(customer)

	if remaining_ingredients.is_empty():
		if bool(customer.get("needs_ingredient_cooking")):
			customer.needs_ingredient_cooking = false
			customer.cart_ingredients_ready = true
		return false

	var submitted_ingredients: Dictionary = {}
	var new_remaining_ingredients: Dictionary = remaining_ingredients.duplicate(true)

	for item_id in remaining_ingredients.keys():
		var item_key: String = str(item_id)
		var remaining_amount: int = int(remaining_ingredients.get(item_key, 0))
		var cooked_amount: int = int(cooked_stock.get(item_key, 0))

		if remaining_amount <= 0:
			new_remaining_ingredients.erase(item_key)
			continue

		if cooked_amount <= 0:
			continue

		var submit_amount: int = int(min(remaining_amount, cooked_amount))

		if submit_amount <= 0:
			continue

		cooked_stock[item_key] = cooked_amount - submit_amount
		submitted_ingredients[item_key] = submit_amount

		var new_amount: int = remaining_amount - submit_amount

		if new_amount <= 0:
			new_remaining_ingredients.erase(item_key)
		else:
			new_remaining_ingredients[item_key] = new_amount

	if submitted_ingredients.is_empty():
		return false

	customer.set_meta("ingredients_to_cook", new_remaining_ingredients)

	if new_remaining_ingredients.is_empty():
		customer.needs_ingredient_cooking = false
		customer.cart_ingredients_ready = true
		print("Customer ingredients are ready.")
	else:
		customer.needs_ingredient_cooking = true
		customer.cart_ingredients_ready = false

	RunSetupData.current_cooked_stock = cooked_stock.duplicate(true)

	print("从大锅熟菜中提交给等待顾客配菜：", submitted_ingredients)
	print("该顾客剩余配菜：", new_remaining_ingredients)
	print("Cooked stock after partial ingredient handoff: ", cooked_stock)

	if cart_pot_layer != null and is_instance_valid(cart_pot_layer):
		refresh_cart_pot_panel()

	return true


func refresh_cart_ingredients_for_pending_customers() -> void:
	for customer in pending_customers:
		if customer == null or not is_instance_valid(customer):
			continue

		if bool(customer.get("order_served")):
			continue

		if bool(customer.get("needs_emergency_purchase")):
			continue

		if bool(customer.get("needs_ingredient_cooking")):
			try_fulfill_cart_ingredients_for_customer(customer)

func hand_over_held_staple_to_waiting_customer() -> Node:
	if held_staple_food_id == "":
		return null

	var held_food_id: String = held_staple_food_id
	var held_food_name: String = get_ingredient_display_name(held_food_id)

	for customer in pending_customers:
		if customer == null or not is_instance_valid(customer):
			continue

		if customer.order_served:
			continue

		if not customer_has_main_food(customer):
			continue

		if not bool(customer.get("needs_main_food_cooking")):
			continue

		if bool(customer.get("cart_main_food_ready")):
			continue

		var customer_main_food: String = str(customer.get_main_food())

		# 兼容两种情况：
		# 1. customer.get_main_food() 返回 "粉丝" / "面"
		# 2. 以后如果改成返回 "glass_noodle" / "noodle"，也能匹配
		if customer_main_food != held_food_name and customer_main_food != held_food_id:
			continue

		customer.needs_main_food_cooking = false
		customer.cart_main_food_ready = true
		held_staple_food_id = ""

		print("Customer main food is ready.")
		print("交出手中主食：", held_food_name)

		return customer

	print("手里有主食，但没有等待这种主食的顾客：", held_food_name)
	return null

func get_first_deliverable_pending_customer() -> Node:
	for customer in pending_customers:
		if customer != null and is_instance_valid(customer):
			if customer.order_served:
				continue

			if customer.needs_emergency_purchase:
				continue

			if customer.can_be_delivered():
				return customer

	return null

func remove_customer_from_queue(customer: Node) -> void:
	var idx := queued_customers.find(customer)
	if idx != -1:
		queued_customers.remove_at(idx)
		refresh_queue_positions()

func remove_customer_from_pending(customer: Node) -> void:
	var idx := pending_customers.find(customer)
	if idx != -1:
		pending_customers.remove_at(idx)

func release_counter_customer(customer: Node) -> void:
	remove_customer_from_queue(customer)
	start_spawn_timer_if_needed()

func notify_customer_leaving(customer: Node) -> void:
	var paid_price := 0

	if customer != null and is_instance_valid(customer):
		if customer.is_checked_out and not customer.order_served:
			if customer.has_method("get_paid_price"):
				paid_price = customer.get_paid_price()
			else:
				paid_price = customer.get_order_price()

	if paid_price > 0:
		money = max(money - paid_price, 0)
		round_income -= paid_price
		today_income -= paid_price
		print("Refund applied because customer left after payment: ", paid_price)

	var game_ui = get_tree().get_first_node_in_group("game_ui")

	if game_ui:
		game_ui.update_money(money)

	remove_customer_from_queue(customer)
	remove_customer_from_pending(customer)
	remove_customer_from_cooker_slots(customer)

	start_spawn_timer_if_needed()

func _on_customer_exited(customer: Node) -> void:
	print("customer exited: ", customer)

	remove_customer_from_queue(customer)
	remove_customer_from_pending(customer)
	remove_customer_from_cooker_slots(customer)

	start_spawn_timer_if_needed()

func _on_spawn_timer_timeout() -> void:
	if not can_spawn_customers_now():
		return

	if queued_customers.size() < max_queue_size:
		spawn_customer()

func print_stocks() -> void:
	print("Cooked stock: ", cooked_stock)
	print("Raw stock: ", raw_stock)
	print("Staple stock: ", staple_stock)

func add_pending_customer(customer: Node) -> void:
	remove_customer_from_queue(customer)

	if not pending_customers.has(customer):
		pending_customers.append(customer)

	if can_spawn_customers_now():
		if queued_customers.size() < max_queue_size:
			spawn_customer()

func has_pending_customer() -> bool:
	for customer in pending_customers:
		if customer != null and is_instance_valid(customer):
			return true
	return false

func is_customer_in_any_cooker(customer: Node) -> bool:
	for i in range(min(unlocked_cooker_slots, cooker_slots.size())):
		var slot = cooker_slots[i]
		if slot["is_busy"] and slot["customer"] == customer:
			return true
	return false

func find_free_cooker_slot_index() -> int:
	for i in range(min(unlocked_cooker_slots, cooker_slots.size())):
		var slot = cooker_slots[i]
		if not slot["is_busy"]:
			return i
	return -1

func get_customer_cooker_slot_index(customer: Node) -> int:
	for i in range(min(unlocked_cooker_slots, cooker_slots.size())):
		var slot = cooker_slots[i]
		if slot["is_busy"] and slot["customer"] == customer:
			return i
	return -1

func remove_customer_from_cooker_slots(customer: Node) -> void:
	for i in range(cooker_slots.size()):
		var slot = cooker_slots[i]
		if slot["customer"] == customer:
			slot["is_busy"] = false
			slot["customer"] = null
			slot["time_left"] = 0.0
			cooker_slots[i] = slot

func start_cooking_pending_order() -> void:
	open_cart_pot_panel()


func start_shop_order_bound_cooking_pending_order() -> void:
	var customer: Node = get_first_uncooked_pending_customer() as Node

	if customer == null:
		if get_first_customer_needing_emergency_purchase() != null:
			print("Need emergency purchase first.")
		else:
			print("No pending order to cook")
		return

	var free_slot_index: int = find_free_cooker_slot_index()

	if free_slot_index == -1:
		print("All unlocked cookers are busy")
		return

	var slot: Dictionary = cooker_slots[free_slot_index] as Dictionary
	slot["is_busy"] = true
	slot["customer"] = customer
	slot["time_left"] = cooker_duration
	cooker_slots[free_slot_index] = slot

	print("Start cooking customer in slot ", free_slot_index, ": ", customer)

func can_fulfill_from_cooked(ingredients: Dictionary) -> bool:
	for ingredient_name in ingredients.keys():
		var amount: int = ingredients[ingredient_name]

		if not cooked_stock.has(ingredient_name):
			return false

		if cooked_stock[ingredient_name] < amount:
			return false

	return true

func can_fulfill_from_combined_stock(ingredients: Dictionary) -> bool:
	for ingredient_name in ingredients.keys():
		var amount: int = ingredients[ingredient_name]

		var cooked_amount: int = max(cooked_stock.get(ingredient_name, 0), 0)
		var raw_amount: int = max(raw_stock.get(ingredient_name, 0), 0)

		if cooked_amount + raw_amount < amount:
			return false

	return true

func get_order_fulfillment_status(ingredients: Dictionary) -> String:
	if can_fulfill_from_cooked(ingredients):
		return "instant"

	if can_fulfill_from_combined_stock(ingredients):
		return "waitable"

	return "unfulfillable"

func deduct_cooked_stock(ingredients: Dictionary) -> void:
	print("Deducting cooked stock...")
	print("Before cooked stock: ", cooked_stock)

	for ingredient_name in ingredients.keys():
		var amount: int = ingredients[ingredient_name]
		if not cooked_stock.has(ingredient_name):
			cooked_stock[ingredient_name] = 0
		cooked_stock[ingredient_name] = max(cooked_stock[ingredient_name] - amount, 0)

	print("After cooked stock: ", cooked_stock)

func consume_raw_stock_for_order(ingredients: Dictionary) -> void:
	print("Consuming raw stock...")
	print("Before raw stock: ", raw_stock)

	for ingredient_name in ingredients.keys():
		var amount: int = int(ingredients[ingredient_name])

		if not raw_stock.has(ingredient_name):
			raw_stock[ingredient_name] = 0

		raw_stock[ingredient_name] = max(int(raw_stock[ingredient_name]) - amount, 0)

	print("After raw stock: ", raw_stock)

func add_cooked_stock_for_order(ingredients: Dictionary) -> void:
	print("Adding cooked stock...")
	print("Before cooked stock: ", cooked_stock)

	for ingredient_name in ingredients.keys():
		var amount: int = int(ingredients[ingredient_name])

		if not cooked_stock.has(ingredient_name):
			cooked_stock[ingredient_name] = 0

		cooked_stock[ingredient_name] = int(cooked_stock[ingredient_name]) + amount

	print("After cooked stock: ", cooked_stock)

func get_cooked_stock_text() -> String:
	var lines: Array[String] = []

	for key in cooked_stock.keys():
		var amount = int(cooked_stock.get(key, 0))
		if amount > 0:
			lines.append("%s x%d" % [TextDB.get_item_name(key), amount])

	if lines.is_empty():
		return TextDB.get_text("UI_ITEM_NONE")

	return ", ".join(lines)

func get_raw_stock_text() -> String:
	var lines: Array[String] = []

	for key in raw_stock.keys():
		var amount = int(raw_stock.get(key, 0))
		if amount > 0:
			lines.append("%s x%d" % [TextDB.get_item_name(key), amount])

	if lines.is_empty():
		return TextDB.get_text("UI_ITEM_NONE")

	return ", ".join(lines)

func get_staple_stock_text() -> String:
	var parts: Array[String] = []

	for item_id in RunSetupData.get_staple_item_ids():
		parts.append("%s x%d" % [
			get_ingredient_display_name(item_id),
			int(staple_stock.get(item_id, 0))
		])

	if parts.is_empty():
		return "无"

	return ", ".join(parts)

func get_customer_main_food_stock_id(customer: Node) -> String:
	if customer == null or not is_instance_valid(customer):
		return "none"

	if not customer.has_method("get_main_food_id"):
		return "none"

	return str(customer.get_main_food_id())


func customer_has_main_food(customer: Node) -> bool:
	var main_food_id := get_customer_main_food_stock_id(customer)

	return main_food_id != "none" and main_food_id != ""


func reserve_main_food_stock_for_customer(customer: Node) -> bool:
	if customer == null or not is_instance_valid(customer):
		return false

	if bool(customer.get_meta("main_food_deducted_at_checkout", false)):
		return true

	if not customer_has_main_food(customer):
		customer.set_meta("main_food_deducted_at_checkout", true)
		customer.set_meta("reserved_main_food_id", "none")
		return true

	var main_food_id := get_customer_main_food_stock_id(customer)

	if int(staple_stock.get(main_food_id, 0)) <= 0:
		print("Main food stock is not enough: ", main_food_id)
		print("Staple stock: ", staple_stock)
		return false

	staple_stock[main_food_id] = int(staple_stock.get(main_food_id, 0)) - 1

	customer.set_meta("main_food_deducted_at_checkout", true)
	customer.set_meta("reserved_main_food_id", main_food_id)

	RunSetupData.current_staple_stock = staple_stock.duplicate(true)

	print("Reserved main food: ", main_food_id)
	print("Staple stock after reserving main food: ", staple_stock)

	return true

func get_zero_food_stock() -> Dictionary:
	return {
		"spinach": 0,
		"potato_slice": 0,
		"tofu_puff": 0
	}

func can_make_ingredient(ingredient_name: String, amount: int) -> bool:
	var cooked_amount: int = max(cooked_stock.get(ingredient_name, 0), 0)
	var raw_amount: int = max(raw_stock.get(ingredient_name, 0), 0)
	return cooked_amount + raw_amount >= amount

func get_adjusted_order(ingredients: Dictionary) -> Dictionary:
	var adjusted_order: Dictionary = {}

	for ingredient_name in ingredients.keys():
		var amount: int = ingredients[ingredient_name]

		if can_make_ingredient(ingredient_name, amount):
			adjusted_order[ingredient_name] = amount

	return adjusted_order

func get_total_pending_emergency_shortage() -> Dictionary:
	var total_ingredient_need: Dictionary = {}
	var total_main_food_need: Dictionary = {}
	var shortage: Dictionary = {}

	for customer in pending_customers:
		if customer == null or not is_instance_valid(customer):
			continue

		if customer.order_served:
			continue

		var remaining_ingredients: Dictionary = get_pending_order_remaining_ingredients(customer)

		for item_id in remaining_ingredients.keys():
			var item_key: String = str(item_id)
			var amount: int = int(remaining_ingredients.get(item_key, 0))

			if amount <= 0:
				continue

			total_ingredient_need[item_key] = int(total_ingredient_need.get(item_key, 0)) + amount

		if customer_has_main_food(customer):
			var main_food_id: String = get_customer_main_food_stock_id(customer)

			if main_food_id != "" and main_food_id != "none":
				if bool(customer.get("needs_main_food_cooking")) and not bool(customer.get("cart_main_food_ready")):
					total_main_food_need[main_food_id] = int(total_main_food_need.get(main_food_id, 0)) + 1

	for item_id in total_ingredient_need.keys():
		var item_key: String = str(item_id)
		var total_need: int = int(total_ingredient_need.get(item_key, 0))
		var cooked_amount: int = int(cooked_stock.get(item_key, 0))
		var raw_amount: int = int(raw_stock.get(item_key, 0))
		var available_amount: int = cooked_amount + raw_amount
		var missing_amount: int = total_need - available_amount

		if missing_amount > 0:
			shortage[item_key] = missing_amount

	for item_id in total_main_food_need.keys():
		var item_key: String = str(item_id)
		var total_need: int = int(total_main_food_need.get(item_key, 0))
		var stock_amount: int = int(staple_stock.get(item_key, 0))
		var assigned_amount: int = get_assigned_staple_food_count(item_key)
		var available_amount: int = stock_amount + assigned_amount
		var missing_amount: int = total_need - available_amount

		if missing_amount > 0:
			shortage[item_key] = int(shortage.get(item_key, 0)) + missing_amount

	return shortage


func refresh_all_pending_emergency_purchase_states() -> void:
	for customer in pending_customers:
		if customer == null or not is_instance_valid(customer):
			continue

		if customer.order_served:
			continue

		var customer_shortage: Dictionary = get_customer_order_shortage_for_emergency(customer)

		if customer_shortage.is_empty():
			customer.needs_emergency_purchase = false
		else:
			customer.needs_emergency_purchase = true

func get_customer_order_shortage_for_emergency(customer: Node) -> Dictionary:
	var shortage: Dictionary = {}

	if customer == null or not is_instance_valid(customer):
		return shortage

	if customer.order_served:
		return shortage

	var remaining_ingredients: Dictionary = get_pending_order_remaining_ingredients(customer)

	for item_id in remaining_ingredients.keys():
		var item_key: String = str(item_id)
		var needed_amount: int = int(remaining_ingredients.get(item_key, 0))

		if needed_amount <= 0:
			continue

		var cooked_amount: int = int(cooked_stock.get(item_key, 0))
		var raw_amount: int = int(raw_stock.get(item_key, 0))
		var available_amount: int = cooked_amount + raw_amount
		var missing_amount: int = needed_amount - available_amount

		if missing_amount > 0:
			shortage[item_key] = missing_amount

	if customer_has_main_food(customer):
		var main_food_id: String = get_customer_main_food_stock_id(customer)

		if main_food_id != "" and main_food_id != "none":
			if bool(customer.get("needs_main_food_cooking")) and not bool(customer.get("cart_main_food_ready")):
				var stock_amount: int = int(staple_stock.get(main_food_id, 0))
				var assigned_amount: int = get_assigned_staple_food_count(main_food_id)
				var available_amount: int = stock_amount + assigned_amount

				if available_amount <= 0:
					shortage[main_food_id] = int(shortage.get(main_food_id, 0)) + 1

	return shortage

func get_order_shortage(ingredients: Dictionary) -> Dictionary:
	var shortage: Dictionary = {}

	for ingredient_name in ingredients.keys():
		var amount: int = ingredients[ingredient_name]

		var cooked_amount: int = max(cooked_stock.get(ingredient_name, 0), 0)
		var raw_amount: int = max(raw_stock.get(ingredient_name, 0), 0)

		var total_amount: int = cooked_amount + raw_amount
		var missing_amount: int = max(amount - total_amount, 0)

		if missing_amount > 0:
			shortage[ingredient_name] = missing_amount

	return shortage

func get_emergency_purchase_cost(shortage: Dictionary) -> int:
	if shortage.is_empty():
		return 0

	return RunSetupData.get_neighbor_emergency_price_for_shortage(shortage)

func emergency_purchase_for_customer(_customer: Node) -> bool:
	var total_shortage: Dictionary = get_total_pending_emergency_shortage()

	if total_shortage.is_empty():
		print("No shortage to purchase.")
		refresh_all_pending_emergency_purchase_states()
		return false

	var cost: int = get_emergency_purchase_cost(total_shortage)

	print("Emergency purchase total shortage: ", total_shortage)
	print("Emergency purchase total cost: ", cost)

	if not spend_money(cost):
		print("Emergency purchase failed.")
		return false

	for item_id in total_shortage.keys():
		var item_key: String = str(item_id)
		var amount: int = int(total_shortage.get(item_key, 0))

		if amount <= 0:
			continue

		if RunSetupData.is_staple_item(item_key):
			if not staple_stock.has(item_key):
				staple_stock[item_key] = 0

			staple_stock[item_key] = int(staple_stock.get(item_key, 0)) + amount
		else:
			if not raw_stock.has(item_key):
				raw_stock[item_key] = 0

			raw_stock[item_key] = int(raw_stock.get(item_key, 0)) + amount

	RunSetupData.current_raw_stock = raw_stock.duplicate(true)
	RunSetupData.current_staple_stock = staple_stock.duplicate(true)

	print("Emergency purchase completed.")
	print("Raw stock after emergency purchase: ", raw_stock)
	print("Staple stock after emergency purchase: ", staple_stock)

	for pending_customer in pending_customers:
		if pending_customer == null or not is_instance_valid(pending_customer):
			continue

		if pending_customer.order_served:
			continue

		reserve_stock_after_emergency_purchase(pending_customer)

	refresh_all_pending_emergency_purchase_states()

	print("Emergency purchase completed for all currently waiting shortages.")
	return true


func reserve_stock_after_emergency_purchase(customer: Node) -> bool:
	if customer == null or not is_instance_valid(customer):
		return false

	if customer.order_served:
		return false

	var remaining_shortage: Dictionary = get_customer_order_shortage_for_emergency(customer)

	if not remaining_shortage.is_empty():
		print("Customer still has shortage after emergency purchase.")
		print("Remaining shortage: ", remaining_shortage)
		customer.needs_emergency_purchase = true
		return false

	if not bool(customer.get_meta("ingredients_deducted_at_checkout", false)):
		if customer.has_method("get_ingredients"):
			var original_ingredients: Dictionary = customer.get_ingredients()

			if not original_ingredients.is_empty():
				if not bool(customer.needs_ingredient_cooking):
					var fulfillment_status: String = get_order_fulfillment_status(original_ingredients)

					if fulfillment_status == "unfulfillable":
						print("Still cannot fulfill ingredients after emergency purchase.")
						print("Remaining ingredient shortage: ", get_order_shortage(original_ingredients))
						customer.needs_emergency_purchase = true
						return false

					prepare_stock_for_waiting_order(customer, fulfillment_status)

	if customer_has_main_food(customer):
		if not bool(customer.get("cart_main_food_ready")):
			customer.needs_main_food_cooking = true

	customer.needs_ingredient_cooking = not get_customer_ingredients_to_cook(customer).is_empty()
	customer.needs_emergency_purchase = false

	print("Emergency purchase stock prepared for customer.")
	print("Raw stock after emergency preparation: ", raw_stock)
	print("Cooked stock after emergency preparation: ", cooked_stock)
	print("Staple stock after emergency preparation: ", staple_stock)

	return true

func get_pending_order_display_text(customer: Node) -> String:
	var base_text: String = str(customer.get_pending_order_summary())

	if order_panel_upgrade_level <= 0:
		return base_text

	var status_id: String = get_pending_order_status_id(customer)
	var status_text: String = TextDB.get_status_name(status_id)

	if order_panel_upgrade_level == 1:
		return TextDB.get_text("UI_PENDING_ORDER_STATUS") % [status_text, base_text]

	if order_panel_upgrade_level == 2:
		if status_id == "cooking":
			var cooker_slot_index: int = get_customer_cooker_slot_index(customer)
			if cooker_slot_index != -1:
				return TextDB.get_text("UI_PENDING_ORDER_STATUS_WITH_POT") % [status_text, cooker_slot_index + 1, base_text]
		return TextDB.get_text("UI_PENDING_ORDER_STATUS") % [status_text, base_text]

	var extra_target_text: String = get_pending_order_delivery_target_text(customer)

	if status_id == "cooking":
		var cooker_slot_index_2: int = get_customer_cooker_slot_index(customer)
		if cooker_slot_index_2 != -1:
			if extra_target_text != "":
				return TextDB.get_text("UI_PENDING_ORDER_STATUS_WITH_POT_TARGET") % [status_text, cooker_slot_index_2 + 1, extra_target_text, base_text]
			return TextDB.get_text("UI_PENDING_ORDER_STATUS_WITH_POT") % [status_text, cooker_slot_index_2 + 1, base_text]

	if extra_target_text != "":
		return TextDB.get_text("UI_PENDING_ORDER_STATUS_WITH_TARGET") % [status_text, extra_target_text, base_text]

	return TextDB.get_text("UI_PENDING_ORDER_STATUS") % [status_text, base_text]

func get_pending_order_remaining_main_food_text(customer: Node) -> String:
	if customer == null or not is_instance_valid(customer):
		return ""

	if not customer_has_main_food(customer):
		return ""

	if not bool(customer.get("needs_main_food_cooking")):
		return ""

	if bool(customer.get("cart_main_food_ready")):
		return ""

	return str(customer.get_main_food())


func get_pending_order_remaining_ingredients(customer: Node) -> Dictionary:
	if customer == null or not is_instance_valid(customer):
		return {}

	if bool(customer.get("cart_ingredients_ready")):
		return {}

	if customer.has_meta("ingredients_to_cook"):
		var ingredients_to_cook = customer.get_meta("ingredients_to_cook")
		if typeof(ingredients_to_cook) == TYPE_DICTIONARY:
			var cleaned_remaining: Dictionary = {}

			for item_id in ingredients_to_cook.keys():
				var item_key := str(item_id)
				var amount := int(ingredients_to_cook.get(item_key, 0))
				if amount > 0:
					cleaned_remaining[item_key] = amount

			return cleaned_remaining

	if not bool(customer.get("needs_ingredient_cooking")):
		return {}

	if customer.has_method("get_ingredients"):
		var ingredients = customer.get_ingredients()
		if typeof(ingredients) == TYPE_DICTIONARY:
			var cleaned_ingredients: Dictionary = {}

			for item_id in ingredients.keys():
				var item_key := str(item_id)
				var amount := int(ingredients.get(item_key, 0))
				if amount > 0:
					cleaned_ingredients[item_key] = amount

			return cleaned_ingredients

	return {}


func get_pending_order_remaining_ingredients_text(customer: Node) -> String:
	var remaining_ingredients: Dictionary = get_pending_order_remaining_ingredients(customer)

	if remaining_ingredients.is_empty():
		return ""

	return get_items_text(remaining_ingredients)


func get_pending_order_card_status_text(customer: Node) -> String:
	if customer == null or not is_instance_valid(customer):
		return ""

	if customer.order_served:
		return "已完成"

	if customer.can_be_delivered() or is_pending_customer_fully_submitted(customer):
		return "可出餐"

	if bool(customer.get("needs_emergency_purchase")):
		return "缺货"

	var remaining_main_food: String = get_pending_order_remaining_main_food_text(customer)
	var remaining_ingredients: Dictionary = get_pending_order_remaining_ingredients(customer)

	if remaining_main_food != "" and not remaining_ingredients.is_empty():
		return "等主食和配菜"

	if remaining_main_food != "":
		return "等主食"

	if not remaining_ingredients.is_empty():
		return "等配菜"

	return "等待确认"

func get_pending_order_card_data(customer: Node) -> Dictionary:
	var patience_text := "%d/%d" % [
		int(ceil(customer.get_display_patience_current())),
		int(customer.get_display_patience_max())
	]

	var status_text := get_pending_order_card_status_text(customer)
	var extra_text := ""

	if order_panel_upgrade_level >= 1:
		var status_id: String = get_pending_order_status_id(customer)
		var upgrade_status_text: String = TextDB.get_status_name(status_id)

		if upgrade_status_text != "":
			status_text = upgrade_status_text

	return {
		"status_text": status_text,
		"main_food_text": get_pending_order_remaining_main_food_text(customer),
		"ingredients_text": get_pending_order_remaining_ingredients_text(customer),
		"patience_text": patience_text,
		"extra_text": extra_text
	}

func get_pending_order_status_id(customer: Node) -> String:
	if customer.needs_emergency_purchase:
		return "waiting_restock"

	if customer.can_be_delivered():
		return "ready_delivery"

	if is_customer_in_any_cooker(customer):
		return "cooking"

	return "waiting_cook"

func get_pending_order_delivery_target_text(_customer: Node) -> String:
	return ""

func add_money(amount: int) -> void:
	if amount <= 0:
		return

	money += amount

	today_gross_income += amount
	round_gross_income += amount

	today_income += amount
	round_income += amount

	var game_ui = get_tree().get_first_node_in_group("game_ui")

	if game_ui:
		game_ui.update_money(money)

	print("Money earned: ", amount)
	print("Current money: ", money)

func get_active_effect_records() -> Array:
	var result: Array = []

	var active_effects_value = RunSetupData.get("active_effects")
	if typeof(active_effects_value) == TYPE_ARRAY:
		for effect_data in active_effects_value:
			if typeof(effect_data) == TYPE_DICTIONARY:
				result.append(effect_data)

	var acquired_effects_value = RunSetupData.get("acquired_effects")
	if typeof(acquired_effects_value) == TYPE_ARRAY:
		for effect_data in acquired_effects_value:
			if typeof(effect_data) == TYPE_DICTIONARY:
				result.append(effect_data)

	return result


func has_effect(effect_id: String) -> bool:
	if effect_id == "":
		return false

	for effect_data in get_active_effect_records():
		var record_effect_id: String = str(effect_data.get("effect_id", ""))
		var record_id: String = str(effect_data.get("id", ""))

		if record_effect_id == effect_id:
			return true

		if record_id == effect_id:
			return true

	return false


func get_effective_cart_pot_batch_duration() -> float:
	var duration: float = cart_pot_batch_duration

	if has_effect("claw_dance"):
		duration *= 0.8

	return max(duration, 0.2)


func get_effective_staple_ladle_duration() -> float:
	var duration: float = staple_ladle_duration

	if has_effect("claw_dance"):
		duration *= 0.8

	return max(duration, 0.2)

func change_reputation(delta: int, reason: String = "") -> void:
	var before_reputation: int = RunSetupData.reputation

	RunSetupData.reputation += delta
	RunSetupData.today_reputation_delta += delta

	print(
		"Reputation changed: ",
		before_reputation,
		" -> ",
		RunSetupData.reputation,
		" | delta: ",
		delta,
		" | reason: ",
		reason
	)

func spend_money(amount: int) -> bool:
	if amount <= 0:
		return true

	if money < amount:
		print("Not enough money. Need: ", amount, " Current: ", money)
		return false

	money -= amount

	today_expense += amount
	round_expense += amount

	today_income -= amount
	round_income -= amount

	var game_ui = get_tree().get_first_node_in_group("game_ui")

	if game_ui:
		game_ui.update_money(money)

	print("Money spent: ", amount)
	print("Current money: ", money)

	return true

func get_today_income() -> int:
	return today_income

func get_run_income() -> int:
	return round_income

func get_waste_value() -> int:
	var waste := 0

	for ingredient_name in raw_stock.keys():
		waste += raw_stock[ingredient_name]

	for ingredient_name in cooked_stock.keys():
		waste += cooked_stock[ingredient_name]

	return waste

func get_round_profit() -> int:
	return round_income - get_waste_value()

func print_round_summary() -> void:
	print("=== 本轮结算 ===")
	print("Today income: ", today_income)
	print("Round income: ", round_income)
	print("Waste value: ", get_waste_value())
	print("Round profit: ", get_round_profit())
	print("Current money: ", money)
	print("Remaining cooked stock: ", cooked_stock)
	print("Remaining raw stock: ", raw_stock)

func try_finish_day() -> void:
	if has_round_finished:
		return

	if is_cleanup_phase:
		return

	if not is_round_closing:
		return

	if not can_enter_cleanup_phase():
		return

	enter_cleanup_phase()

func can_enter_cleanup_phase() -> bool:
	if has_round_finished:
		return false

	if not is_round_closing:
		return false

	if has_active_customers_or_orders():
		return false

	if has_busy_cooker():
		return false

	return true


func has_active_customers_or_orders() -> bool:
	for customer in queued_customers:
		if _customer_blocks_cart_cleanup(customer):
			return true

	for customer in pending_customers:
		if _customer_blocks_cart_cleanup(customer):
			return true

	if characters_node != null and is_instance_valid(characters_node):
		for child in characters_node.get_children():
			if _customer_blocks_cart_cleanup(child):
				return true

	var customer_nodes := get_tree().get_nodes_in_group("customers")

	for customer in customer_nodes:
		if _customer_blocks_cart_cleanup(customer):
			return true

	return false

func _customer_blocks_cart_cleanup(customer: Node) -> bool:
	if customer == null:
		return false

	if not is_instance_valid(customer):
		return false

	if not customer.is_in_group("customers"):
		return false

	if customer.has_method("blocks_cart_cleanup"):
		return bool(customer.blocks_cart_cleanup())

	# 兜底逻辑：
	# 如果某个顾客脚本还没有 blocks_cart_cleanup()，
	# 至少不要让已经服务完成或已经因耐心离开的顾客阻止收摊。
	if bool(customer.get("order_served")):
		return false

	if bool(customer.get("leaving_due_to_patience")):
		return false

	return true

func has_busy_cooker() -> bool:
	if cart_pot_is_cooking:
		return true

	if has_busy_staple_ladle():
		return true

	for i in range(min(unlocked_cooker_slots, cooker_slots.size())):
		var slot: Dictionary = cooker_slots[i] as Dictionary

		if bool(slot.get("is_busy", false)):
			return true

	return false


func enter_cleanup_phase() -> void:
	is_cleanup_phase = true
	is_open_for_business = false
	is_round_closing = true

	if spawn_timer != null and is_instance_valid(spawn_timer):
		spawn_timer.stop()

	var game_ui = get_tree().get_first_node_in_group("game_ui")
	if game_ui:
		game_ui.hide_order()
		game_ui.hide_patience()
		game_ui.hide_pending_orders()
		game_ui.update_business_state(
			day_time_left,
			is_open_for_business,
			is_round_closing,
			has_round_finished,
			is_cleanup_phase
		)

	print("=== 进入收摊整理阶段 ===")
	print("玩家可以在收银台按 E 进入结算。")


func can_finalize_day_now() -> bool:
	return is_cleanup_phase and not has_round_finished


func finish_day_from_cleanup() -> void:
	if not can_finalize_day_now():
		print("当前还不能进入结算。")
		return

	print("=== 收摊完成，进入日结 ===")
	finish_day()

func can_finish_day_now() -> bool:
	for slot in cooker_slots:
		if bool(slot.get("is_busy", false)):
			return false

	var customers = get_tree().get_nodes_in_group("customers")
	for customer in customers:
		if customer != null and is_instance_valid(customer):
			return false

	return true

func clear_staple_ladle_and_held_food_at_day_end() -> Dictionary:
	var discarded: Dictionary = {
		"held_raw": "",
		"held": "",
		"ladles": []
	}

	if held_raw_staple_food_id != "":
		discarded["held_raw"] = held_raw_staple_food_id
		held_raw_staple_food_id = ""

	if held_staple_food_id != "":
		discarded["held"] = held_staple_food_id
		held_staple_food_id = ""

	for i in range(staple_ladle_slots.size()):
		var slot: Dictionary = staple_ladle_slots[i] as Dictionary
		var state: String = str(slot.get("state", "empty"))
		var main_food_id: String = str(slot.get("main_food_id", ""))

		if state != "empty" or main_food_id != "":
			discarded["ladles"].append({
				"slot": i,
				"state": state,
				"main_food_id": main_food_id
			})

		slot["state"] = "empty"
		slot["main_food_id"] = ""
		slot["time_left"] = 0.0
		slot["is_ready"] = false
		staple_ladle_slots[i] = slot

	return discarded

func finish_day() -> void:
	has_round_finished = true

	var remaining_cooked_stock := cooked_stock.duplicate(true)
	var remaining_raw_stock := raw_stock.duplicate(true)
	var remaining_staple_stock := staple_stock.duplicate(true)
	var discarded_staple_food := clear_staple_ladle_and_held_food_at_day_end()

	RunSetupData.run_money = money
	RunSetupData.run_total_income = round_income
	RunSetupData.run_gross_income = round_gross_income
	RunSetupData.run_total_expense = round_expense

	RunSetupData.current_raw_stock = remaining_raw_stock
	RunSetupData.current_staple_stock = remaining_staple_stock

	# 熟食不隔夜：日结显示剩余熟食，但下一天不继承熟食。
	RunSetupData.current_cooked_stock = get_zero_food_stock()

	RunSetupData.generated_night_queue = build_night_queue_from_today_results()

	var day_summary := {
		"day_index": RunSetupData.current_day_in_run,
		"total_days": RunSetupData.total_days_in_run,

		"today_gross_income": today_gross_income,
		"today_expense": today_expense,
		"today_net_income": today_income,

		"run_gross_income": round_gross_income,
		"run_expense": round_expense,
		"run_net_income": round_income,

		"current_money": money,

		"cooked_stock_text": get_cooked_stock_text(),
		"raw_stock_text": "%s\n主食库存：%s" % [
			get_raw_stock_text(),
			get_staple_stock_text()
		],
		"cooked_stock_data": remaining_cooked_stock,
		"raw_stock_data": remaining_raw_stock,
		"staple_stock_data": remaining_staple_stock,

		"discarded_staple_food": discarded_staple_food,

		"today_reputation_delta": RunSetupData.today_reputation_delta,
		"shop_reputation": RunSetupData.shop_reputation,
		"today_echo_lines": RunSetupData.get_today_stall_echo_lines(),

		"cooked_stock_discarded": true
	}

	RunSetupData.last_day_summary = day_summary

	if RunSetupData.current_day_in_run >= RunSetupData.total_days_in_run:
		finish_run()
		return

	RunSetupData.settlement_view_mode = "day"

	print("=== 第 %d 天结束 ===" % RunSetupData.current_day_in_run)
	print("Today gross income: ", today_gross_income)
	print("Today expense: ", today_expense)
	print("Today net income: ", today_income)
	print("Run net income so far: ", round_income)
	print("Current money: ", money)
	print("Today reputation delta: ", RunSetupData.today_reputation_delta)
	print("Current reputation: ", RunSetupData.shop_reputation)
	print("Remaining cooked stock this day: ", remaining_cooked_stock)
	print("Cooked stock will not carry over to next day.")
	print("Raw stock carried over: ", remaining_raw_stock)
	print("Staple stock carried over: ", remaining_staple_stock)
	print("Discarded staple food at day end: ", discarded_staple_food)
	print("Generated night queue: ", RunSetupData.generated_night_queue)

	get_tree().call_deferred("change_scene_to_file", "res://settlement_result.tscn")

func finish_run() -> void:
	var remaining_cooked_stock := cooked_stock.duplicate(true)
	var remaining_raw_stock := raw_stock.duplicate(true)
	var remaining_staple_stock := staple_stock.duplicate(true)

	RunSetupData.current_raw_stock = remaining_raw_stock
	RunSetupData.current_staple_stock = remaining_staple_stock

	var run_summary := {
		"total_days": RunSetupData.total_days_in_run,
		"today_gross_income": today_gross_income,
		"today_expense": today_expense,
		"today_net_income": today_income,
		"run_gross_income": round_gross_income,
		"run_expense": round_expense,
		"run_net_income": round_income,
		"current_money": money,
		"cooked_stock_text": get_cooked_stock_text(),
		"raw_stock_text": "%s\n主食库存：%s" % [
			get_raw_stock_text(),
			get_staple_stock_text()
		],
		"cooked_stock_data": remaining_cooked_stock,
		"raw_stock_data": remaining_raw_stock,
		"staple_stock_data": remaining_staple_stock,
		"today_reputation_delta": RunSetupData.today_reputation_delta,
		"shop_reputation": RunSetupData.shop_reputation,
		"today_echo_lines": RunSetupData.get_today_stall_echo_lines(),
		"cooked_stock_discarded": true
	}

	RunSetupData.last_run_summary = run_summary
	RunSetupData.settlement_view_mode = "run"
	RunSetupData.current_cooked_stock = get_zero_food_stock()

	print("=== 本轮结算 ===")
	print("Today gross income: ", today_gross_income)
	print("Today expense: ", today_expense)
	print("Today net income: ", today_income)
	print("Run gross income: ", round_gross_income)
	print("Run expense: ", round_expense)
	print("Run net income: ", round_income)
	print("Current money: ", money)
	print("Today reputation delta: ", RunSetupData.today_reputation_delta)
	print("Current reputation: ", RunSetupData.shop_reputation)
	print("Remaining cooked stock this day: ", remaining_cooked_stock)
	print("Cooked stock is discarded at end of day/run.")
	print("Remaining raw stock: ", remaining_raw_stock)
	print("Remaining staple stock: ", remaining_staple_stock)

	get_tree().call_deferred("change_scene_to_file", "res://settlement_result.tscn")
