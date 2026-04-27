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

var planned_raw_stock: Dictionary = {
	"spinach": 4,
	"potato_slice": 4,
	"tofu_puff": 4
}

var planned_cooked_stock: Dictionary = {
	"spinach": 2,
	"potato_slice": 2,
	"tofu_puff": 2
}

var raw_stock: Dictionary = {}
var cooked_stock: Dictionary = {}

var staple_stock: Dictionary = {}
var planned_staple_stock: Dictionary = {
	"glass_noodle": 10,
	"noodle": 10
}

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


func show_storage_stock_only() -> void:
	var game_ui = get_tree().get_first_node_in_group("game_ui")

	if game_ui:
		game_ui.show_stock(
			get_cooked_stock_text(),
			get_raw_stock_text()
		)


func get_ingredient_display_name(item_id: String) -> String:
	match item_id:
		"spinach":
			return "菠菜"
		"potato_slice":
			return "土豆片"
		"tofu_puff":
			return "豆腐泡"
		"glass_noodle":
			return "粉丝"
		"noodle":
			return "面"
		_:
			return item_id


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

	var item_pool: Array[String] = [
		"spinach",
		"potato_slice",
		"tofu_puff"
	]

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
	var reserved_raw_to_cook: Dictionary = {}

	if fulfillment_status == "instant":
		deduct_cooked_stock(ingredients)
		customer.set_meta("reserved_cooked_ingredients", ingredients.duplicate(true))
		customer.set_meta("ingredients_to_cook", {})
		customer.set_meta("ingredients_deducted_at_checkout", true)
		return

	if fulfillment_status == "waitable":
		print("Reserving stock for waiting order...")
		print("Before cooked stock: ", cooked_stock)
		print("Before raw stock: ", raw_stock)

		for ingredient_name in ingredients.keys():
			var needed_amount: int = int(ingredients[ingredient_name])
			var available_cooked: int = int(max(cooked_stock.get(ingredient_name, 0), 0))

			var reserve_cooked_amount: int = min(available_cooked, needed_amount)
			var missing_amount: int = max(needed_amount - reserve_cooked_amount, 0)

			if reserve_cooked_amount > 0:
				reserved_cooked[ingredient_name] = reserve_cooked_amount
				cooked_stock[ingredient_name] = available_cooked - reserve_cooked_amount

			if missing_amount > 0:
				reserved_raw_to_cook[ingredient_name] = missing_amount

				if not raw_stock.has(ingredient_name):
					raw_stock[ingredient_name] = 0

				raw_stock[ingredient_name] = max(int(raw_stock[ingredient_name]) - missing_amount, 0)

		customer.set_meta("reserved_cooked_ingredients", reserved_cooked)
		customer.set_meta("ingredients_to_cook", reserved_raw_to_cook)
		customer.set_meta("ingredients_deducted_at_checkout", true)

		print("Reserved cooked ingredients: ", reserved_cooked)
		print("Reserved raw ingredients for cooking: ", reserved_raw_to_cook)
		print("After cooked stock: ", cooked_stock)
		print("After raw stock: ", raw_stock)
		return

	customer.set_meta("reserved_cooked_ingredients", {})
	customer.set_meta("ingredients_to_cook", {})
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

	var fulfillment_status: String = get_order_fulfillment_status(customer.get_ingredients())
	var has_main_food: bool = customer.get_main_food_id() != "none"
	var needs_waiting: bool = has_main_food or fulfillment_status != "instant"
	var needs_main_food_cooking: bool = has_main_food
	var needs_ingredient_cooking: bool = fulfillment_status == "waitable"
	var needs_emergency_purchase: bool = fulfillment_status == "unfulfillable"

	result["status"] = "ok"
	result["needs_waiting"] = needs_waiting
	result["needs_main_food_cooking"] = needs_main_food_cooking
	result["needs_ingredient_cooking"] = needs_ingredient_cooking
	result["needs_emergency_purchase"] = needs_emergency_purchase
	result["fulfillment_status"] = fulfillment_status
	result["shortage"] = get_order_shortage(customer.get_ingredients())

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

	if not reserve_main_food_stock_for_customer(customer):
		customer.needs_main_food_cooking = needs_main_food_cooking
		customer.needs_ingredient_cooking = needs_ingredient_cooking
		customer.needs_emergency_purchase = true

		customer.start_waiting_for_food(needs_main_food_cooking, needs_ingredient_cooking)

		var missing_main_food_delivery_spot = get_tree().get_first_node_in_group("delivery_spot")

		if missing_main_food_delivery_spot:
			customer.go_to_delivery(missing_main_food_delivery_spot.global_position)
		else:
			print("No delivery spot found.")

		pending_customers.append(customer)
		release_counter_customer(customer)

		print("Customer paid, but main food stock is missing. Customer needs emergency purchase.")

		return "waiting_emergency"

	if needs_emergency_purchase:
		customer.needs_main_food_cooking = needs_main_food_cooking
		customer.needs_ingredient_cooking = needs_ingredient_cooking
		customer.needs_emergency_purchase = true

		customer.start_waiting_for_food(needs_main_food_cooking, needs_ingredient_cooking)

		var emergency_delivery_spot = get_tree().get_first_node_in_group("delivery_spot")

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

			var instant_exit_point = get_tree().get_first_node_in_group("exit_point")

			if instant_exit_point:
				customer.go_to_exit(instant_exit_point.global_position)

			release_counter_customer(customer)

			print("Customer paid and took food immediately.")

			return "instant_leave"

		customer.needs_main_food_cooking = needs_main_food_cooking
		customer.needs_ingredient_cooking = false
		customer.needs_emergency_purchase = false

		customer.start_waiting_for_food(needs_main_food_cooking, false)

		var instant_delivery_spot = get_tree().get_first_node_in_group("delivery_spot")

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

		customer.needs_main_food_cooking = needs_main_food_cooking
		customer.needs_ingredient_cooking = needs_ingredient_cooking
		customer.needs_emergency_purchase = false

		customer.start_waiting_for_food(needs_main_food_cooking, needs_ingredient_cooking)

		var waitable_delivery_spot = get_tree().get_first_node_in_group("delivery_spot")

		if waitable_delivery_spot:
			customer.go_to_delivery(waitable_delivery_spot.global_position)
		else:
			print("No delivery spot found.")

		pending_customers.append(customer)
		release_counter_customer(customer)

		print("Customer paid and is now waiting for food.")

		return "waiting_delivery"

	customer.needs_main_food_cooking = needs_main_food_cooking
	customer.needs_ingredient_cooking = needs_ingredient_cooking
	customer.needs_emergency_purchase = true

	customer.start_waiting_for_food(needs_main_food_cooking, needs_ingredient_cooking)

	var fallback_delivery_spot = get_tree().get_first_node_in_group("delivery_spot")

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

func complete_delivery_for_customer(customer: Node) -> bool:
	if customer == null or not is_instance_valid(customer):
		print("Cannot deliver: invalid customer.")
		return false

	if not customer.can_be_delivered():
		print("Cannot deliver: customer order is not ready.")
		return false

	customer.mark_order_served()

	if has_method("handle_customer_order_completed"):
		handle_customer_order_completed(customer)

	remove_customer_from_pending(customer)

	var exit_point = get_tree().get_first_node_in_group("exit_point")
	if exit_point:
		customer.go_to_exit(exit_point.global_position)

	print("Delivered order to customer.")
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
	for customer in pending_customers:
		if customer != null and is_instance_valid(customer):
			if customer.needs_emergency_purchase and not customer.order_served:
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

func get_first_deliverable_pending_customer() -> Node:
	for customer in pending_customers:
		if customer != null and is_instance_valid(customer):
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
	var customer = get_first_uncooked_pending_customer()
	if customer == null:
		if get_first_customer_needing_emergency_purchase() != null:
			print("Need emergency purchase first.")
		else:
			print("No pending order to cook")
		return

	var free_slot_index = find_free_cooker_slot_index()
	if free_slot_index == -1:
		print("All unlocked cookers are busy")
		return

	var slot = cooker_slots[free_slot_index]
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
	var cost := RunSetupData.get_neighbor_emergency_price_for_shortage(shortage)

	if cost <= 0:
		return 0

	print("Neighbor emergency stock cost: ", cost, " | shortage: ", shortage)

	return cost

func emergency_purchase_for_customer(customer: Node) -> bool:
	if customer == null or not is_instance_valid(customer):
		print("No customer for emergency purchase.")
		return false

	var shortage: Dictionary = get_order_shortage(customer.get_ingredients())

	if shortage.is_empty():
		print("No shortage to purchase. Try reserving stock for this order.")
		return reserve_stock_after_emergency_purchase(customer)

	var cost: int = get_emergency_purchase_cost(shortage)

	print("Emergency purchase shortage: ", shortage)
	print("Emergency purchase cost: ", cost)

	if not spend_money(cost):
		print("Emergency purchase failed.")
		return false

	for ingredient_name in shortage.keys():
		if not raw_stock.has(ingredient_name):
			raw_stock[ingredient_name] = 0

		raw_stock[ingredient_name] = int(raw_stock[ingredient_name]) + int(shortage[ingredient_name])

	print("Emergency purchase completed.")
	print("Raw stock after emergency purchase: ", raw_stock)

	if not reserve_stock_after_emergency_purchase(customer):
		print("Emergency purchase completed, but stock still cannot be reserved for this order.")
		return false

	print("Emergency purchase stock reserved for customer.")
	print("Raw stock after reserving emergency order: ", raw_stock)
	print("Cooked stock after reserving emergency order: ", cooked_stock)

	return true


func reserve_stock_after_emergency_purchase(customer: Node) -> bool:
	if customer == null or not is_instance_valid(customer):
		return false

	if bool(customer.get_meta("ingredients_deducted_at_checkout", false)):
		customer.needs_emergency_purchase = false
		return true

	var fulfillment_status: String = get_order_fulfillment_status(customer.get_ingredients())

	if fulfillment_status == "unfulfillable":
		print("Still cannot fulfill order after emergency purchase.")
		print("Remaining shortage: ", get_order_shortage(customer.get_ingredients()))
		return false

	prepare_stock_for_waiting_order(customer, fulfillment_status)

	customer.needs_emergency_purchase = false

	if fulfillment_status == "waitable":
		customer.needs_ingredient_cooking = true
	else:
		customer.needs_ingredient_cooking = false

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

func get_pending_order_card_data(customer: Node) -> Dictionary:
	var patience_text := "%d/%d" % [
		int(ceil(customer.get_display_patience_current())),
		int(customer.get_display_patience_max())
	]

	var status_text := ""
	var extra_text := ""

	if order_panel_upgrade_level >= 1:
		var status_id: String = get_pending_order_status_id(customer)
		status_text = TextDB.get_status_name(status_id)

	return {
		"status_text": status_text,
		"main_food_text": customer.get_main_food(),
		"ingredients_text": customer.get_ingredients_text(),
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
	for i in range(min(unlocked_cooker_slots, cooker_slots.size())):
		var slot = cooker_slots[i]

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

func finish_day() -> void:
	has_round_finished = true

	var remaining_cooked_stock := cooked_stock.duplicate(true)
	var remaining_raw_stock := raw_stock.duplicate(true)
	var remaining_staple_stock := staple_stock.duplicate(true)

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
	print("Generated night queue: ", RunSetupData.generated_night_queue)

	get_tree().call_deferred("change_scene_to_file", "res://settlement_result.tscn")

func finish_run() -> void:
	var remaining_cooked_stock := cooked_stock.duplicate(true)
	var remaining_raw_stock := raw_stock.duplicate(true)

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
		"raw_stock_text": get_raw_stock_text(),
		"cooked_stock_data": remaining_cooked_stock,
		"raw_stock_data": remaining_raw_stock,

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

	get_tree().call_deferred("change_scene_to_file", "res://settlement_result.tscn")
