extends Node

@export var customer_scene: PackedScene

var queued_customers: Array = []
var pending_customers: Array = []

var money: int = 0
var round_income: int = 0
var round_index: int = 1
var today_income: int = 0

var is_open_for_business: bool = false
var is_round_closing: bool = false
var has_round_finished: bool = false

var day_duration_seconds: float = 15.0
var day_time_left: float = 90.0
var auto_close_triggered: bool = false

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
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	_apply_upgrade_flags()
	initialize_cooker_slots()
	start_round()

func _process(delta: float) -> void:
	update_day_timer(delta)
	update_cooker_slots(delta)

	if is_round_closing and not has_round_finished:
		try_finish_day()

	var game_ui = get_tree().get_first_node_in_group("game_ui")
	if game_ui == null:
		return

	game_ui.update_business_state(day_time_left, is_open_for_business, is_round_closing, has_round_finished)
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

	print("=== 今日时间已耗尽，未开业也进入结算 ===")

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
	initialize_round_stocks()
	_apply_upgrade_flags()
	initialize_cooker_slots()
	apply_station_layout_from_run_setup()

	money = RunSetupData.run_money
	round_income = RunSetupData.run_total_income
	today_income = 0

	is_open_for_business = false
	is_round_closing = false
	has_round_finished = false

	day_time_left = day_duration_seconds
	auto_close_triggered = false

	RunSetupData.today_special_customer_results = []
	RunSetupData.generated_night_queue = []

	RunSetupData.setup_daily_special_customer_plan()

	print("=== 当前天开始 ===")
	print("Day: ", RunSetupData.current_day_in_run, "/", RunSetupData.total_days_in_run)
	print("Selected stage id: ", RunSetupData.selected_stage_id)
	print("Selected difficulty days: ", RunSetupData.selected_difficulty_days)
	print("Station layout from RunSetupData: ", RunSetupData.station_layout)
	print_stocks()

	var game_ui = get_tree().get_first_node_in_group("game_ui")
	if game_ui:
		game_ui.update_money(money)
		game_ui.hide_order()
		game_ui.hide_stock()
		game_ui.hide_patience()
		game_ui.hide_pending_orders()
		game_ui.update_business_state(day_time_left, is_open_for_business, is_round_closing, has_round_finished)

	queued_customers.clear()
	pending_customers.clear()

	if spawn_timer != null and is_instance_valid(spawn_timer):
		spawn_timer.stop()

	print("当前未开业，不生成普通顾客。")

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

	raw_stock = RunSetupData.current_raw_stock.duplicate(true)
	cooked_stock = RunSetupData.current_cooked_stock.duplicate(true)

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

	RunSetupData.today_special_customer_results.append({
		"type": special_type,
		"name": special_name,
		"result": result
	})

	customer.set("special_result_recorded", true)

	print("Recorded special customer result: ", {
		"type": special_type,
		"name": special_name,
		"result": result
	})

func handle_customer_order_completed(customer: Node) -> void:
	record_special_customer_result(customer, "good")

func handle_customer_patience_timeout(customer: Node) -> void:
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

	if fulfillment_status == "instant":
		prepare_stock_for_waiting_order(customer, fulfillment_status)

		if not needs_waiting:
			customer.mark_order_served()

			if has_method("handle_customer_order_completed"):
				handle_customer_order_completed(customer)

			var exit_point = get_tree().get_first_node_in_group("exit_point")
			if exit_point:
				customer.go_to_exit(exit_point.global_position)

			release_counter_customer(customer)
			print("Customer paid and took food immediately.")
			return "instant_leave"

	if fulfillment_status == "waitable":
		prepare_stock_for_waiting_order(customer, fulfillment_status)

	customer.needs_main_food_cooking = needs_main_food_cooking
	customer.needs_ingredient_cooking = needs_ingredient_cooking
	customer.needs_emergency_purchase = needs_emergency_purchase

	customer.start_waiting_for_food(needs_main_food_cooking, needs_ingredient_cooking)

	var delivery_spot = get_tree().get_first_node_in_group("delivery_spot")
	if delivery_spot:
		customer.go_to_delivery(delivery_spot.global_position)
	else:
		print("No delivery spot found. Customer stays in current position.")

	add_pending_customer(customer)

	if needs_emergency_purchase:
		print("Customer paid, but order currently needs emergency purchase.")
		return "waiting_emergency"

	print("Customer paid and is now waiting for food.")
	return "waiting_delivery"

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
		{"type": "insight", "name": "小猫领悟", "result": "neutral"}
	]

	for entry in RunSetupData.today_special_customer_results:
		var result_text: String = str(entry.get("result", "neutral"))
		var entry_name: String = str(entry.get("name", "特殊客人"))

		if result_text == "good":
			queue.append({
				"type": "good",
				"name": entry_name,
				"result": "good"
			})
		elif result_text == "bad":
			queue.append({
				"type": "bad",
				"name": entry_name,
				"result": "bad"
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

	var game_ui = get_tree().get_first_node_in_group("game_ui")
	if game_ui:
		game_ui.hide_order()

	var exit_point = get_tree().get_first_node_in_group("exit_point")
	if exit_point:
		customer.go_to_exit(exit_point.global_position)

	release_counter_customer(customer)
	print("Customer leaves before checkout.")

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

	if can_spawn_customers_now():
		if queued_customers.size() < max_queue_size:
			if spawn_timer != null and is_instance_valid(spawn_timer) and spawn_timer.is_inside_tree():
				spawn_timer.start()

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

	if can_spawn_customers_now():
		if queued_customers.size() < max_queue_size:
			if spawn_timer != null and is_instance_valid(spawn_timer) and spawn_timer.is_inside_tree():
				spawn_timer.start()

func _on_customer_exited(customer: Node) -> void:
	print("customer exited: ", customer)
	remove_customer_from_queue(customer)
	remove_customer_from_pending(customer)
	remove_customer_from_cooker_slots(customer)

	if can_spawn_customers_now():
		if queued_customers.size() < max_queue_size:
			if spawn_timer != null and is_instance_valid(spawn_timer) and spawn_timer.is_inside_tree():
				spawn_timer.start()

func _on_spawn_timer_timeout() -> void:
	if not can_spawn_customers_now():
		return

	if queued_customers.size() < max_queue_size:
		spawn_customer()

func print_stocks() -> void:
	print("Cooked stock: ", cooked_stock)
	print("Raw stock: ", raw_stock)

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
	var total_cost := 0

	for ingredient_name in shortage.keys():
		total_cost += shortage[ingredient_name] * 3

	return total_cost

func emergency_purchase_for_customer(customer: Node) -> bool:
	if customer == null:
		print("No customer for emergency purchase.")
		return false

	var shortage: Dictionary = get_order_shortage(customer.get_ingredients())

	if shortage.is_empty():
		print("No shortage to purchase.")
		return true

	var cost: int = get_emergency_purchase_cost(shortage)
	print("Emergency purchase shortage: ", shortage)
	print("Emergency purchase cost: ", cost)

	if not spend_money(cost):
		print("Emergency purchase failed.")
		return false

	for ingredient_name in shortage.keys():
		if not raw_stock.has(ingredient_name):
			raw_stock[ingredient_name] = 0
		raw_stock[ingredient_name] += shortage[ingredient_name]

	print("Emergency purchase completed.")
	print("Raw stock after emergency purchase: ", raw_stock)
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
	money += amount
	round_income += amount
	today_income += amount

	print("Money earned: ", amount)
	print("Current money: ", money)

	var game_ui = get_tree().get_first_node_in_group("game_ui")
	if game_ui:
		game_ui.update_money(money)

func spend_money(amount: int) -> bool:
	if money < amount:
		print("Not enough money.")
		return false

	money -= amount
	round_income -= amount
	today_income -= amount

	print("Money spent: ", amount)
	print("Current money: ", money)

	var game_ui = get_tree().get_first_node_in_group("game_ui")
	if game_ui:
		game_ui.update_money(money)

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
	if not is_round_closing:
		return

	if has_round_finished:
		return

	if not can_finish_day_now():
		return

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

	RunSetupData.run_money = money
	RunSetupData.run_total_income = round_income
	RunSetupData.current_raw_stock = raw_stock.duplicate(true)
	RunSetupData.current_cooked_stock = cooked_stock.duplicate(true)
	RunSetupData.generated_night_queue = build_night_queue_from_today_results()

	var day_summary := {
		"day_index": RunSetupData.current_day_in_run,
		"total_days": RunSetupData.total_days_in_run,
		"today_income": today_income,
		"run_income": round_income,
		"current_money": money,
		"cooked_stock_text": get_cooked_stock_text(),
		"raw_stock_text": get_raw_stock_text()
	}

	RunSetupData.last_day_summary = day_summary

	if RunSetupData.current_day_in_run >= RunSetupData.total_days_in_run:
		finish_run()
		return

	RunSetupData.settlement_view_mode = "day"

	print("=== 第 %d 天结束 ===" % RunSetupData.current_day_in_run)
	print("Today income: ", today_income)
	print("Run income so far: ", round_income)
	print("Current money: ", money)
	print("Remaining cooked stock: ", cooked_stock)
	print("Remaining raw stock: ", raw_stock)
	print("Generated night queue: ", RunSetupData.generated_night_queue)

	get_tree().call_deferred("change_scene_to_file", "res://settlement_result.tscn")

func finish_run() -> void:
	RunSetupData.settlement_view_mode = "run"

	var run_summary := {
		"total_days": RunSetupData.total_days_in_run,
		"run_income": round_income,
		"current_money": money,
		"cooked_stock_text": get_cooked_stock_text(),
		"raw_stock_text": get_raw_stock_text()
	}

	RunSetupData.last_run_summary = run_summary

	print("=== 本轮完成 ===")
	print("Total days: ", RunSetupData.total_days_in_run)
	print("Run income: ", round_income)
	print("Current money: ", money)
	print("Remaining cooked stock: ", cooked_stock)
	print("Remaining raw stock: ", raw_stock)

	get_tree().call_deferred("change_scene_to_file", "res://settlement_result.tscn")
