extends Node

const BusinessDaySystemScript = preload("res://gameplay/systems/business_day_system.gd")
const CustomerQueueSystemScript = preload("res://gameplay/systems/customer_queue_system.gd")
const PendingOrderSystemScript = preload("res://gameplay/systems/pending_order_system.gd")
const OrderSystemScript = preload("res://gameplay/systems/order_system.gd")
const InventorySystemScript = preload("res://gameplay/systems/inventory_system.gd")
const CookingSystemScript = preload("res://gameplay/systems/cooking_system.gd")
const SupplierSystemScript = preload("res://gameplay/systems/supplier_system.gd")
const EmergencyPurchaseSystemScript = preload("res://gameplay/systems/emergency_purchase_system.gd")
const ReputationSystemScript = preload("res://gameplay/systems/reputation_system.gd")
const SettlementBuilderScript = preload("res://gameplay/systems/settlement_builder.gd")
const DayEventSystemScript = preload("res://gameplay/systems/day_event_system.gd")
const StationLayoutSystemScript = preload("res://gameplay/systems/station_layout_system.gd")
const StockUtils = preload("res://gameplay/models/stock_utils.gd")
const CustomerOrderState = preload("res://gameplay/models/customer_order_state.gd")

@export var customer_scene: PackedScene

var business_day_system: BusinessDaySystem
var customer_queue_system: CustomerQueueSystem
var pending_order_system: PendingOrderSystem
var order_system: OrderSystem
var inventory_system: InventorySystem
var cooking_system: CookingSystem
var supplier_system: SupplierSystem
var emergency_purchase_system: EmergencyPurchaseSystem
var reputation_system: ReputationSystem
var settlement_builder: SettlementBuilder
var day_event_system: DayEventSystem
var station_layout_system: StationLayoutSystem

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

var base_spawn_timer_wait_time: float = 1.0

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

var has_opened_for_business_today: bool = false

var max_queue_size: int = 3

# å¤šé”…ç³»ç»Ÿ
var total_cooker_slots: int = 2
var unlocked_cooker_slots: int = 1
var cooker_duration: float = 3.0

# è®¢å•æŒ‚ä»¶å‡çº§å±‚çº§
# 0 = åŸºç¡€æŒ‚ä»¶ï¼ˆä¸»é£Ÿ/é£Ÿæ/è€å¿ƒï¼‰
# 1 = æ˜¾ç¤ºçŠ¶æ€
# 2 = æ˜¾ç¤ºçŠ¶æ€ + é”…ä½
# 3 = æ˜¾ç¤ºçŠ¶æ€ + é”…ä½ + é€é¤ç›®æ ‡ï¼ˆå…ˆç•™æŽ¥å£ï¼‰
var order_panel_upgrade_level: int = 0

# å…¶ä»–å‡çº§ / å±€å†…å±è”½
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
@onready var glass_noodle_basket_node: Node2D = $"../Stations/GlassNoodleBasket"
@onready var noodle_basket_node: Node2D = $"../Stations/NoodleBasket"
@onready var staple_ladle_1_node: Node2D = $"../Stations/StapleLadle1"
@onready var staple_ladle_2_node: Node2D = $"../Stations/StapleLadle2"
@onready var gift_box_node: Node2D = $"../Stations/GiftBox"

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

	initialize_systems()
	debug_validate_runtime()
	_apply_upgrade_flags()
	initialize_cooker_slots()
	start_round()


func initialize_systems() -> void:
	business_day_system = BusinessDaySystemScript.new()
	customer_queue_system = CustomerQueueSystemScript.new()
	pending_order_system = PendingOrderSystemScript.new()
	order_system = OrderSystemScript.new()
	inventory_system = InventorySystemScript.new()
	cooking_system = CookingSystemScript.new()
	supplier_system = SupplierSystemScript.new()
	emergency_purchase_system = EmergencyPurchaseSystemScript.new()
	reputation_system = ReputationSystemScript.new()
	settlement_builder = SettlementBuilderScript.new()
	day_event_system = DayEventSystemScript.new()
	station_layout_system = StationLayoutSystemScript.new()

	for system in [
		business_day_system,
		customer_queue_system,
		pending_order_system,
		order_system,
		inventory_system,
		cooking_system,
		supplier_system,
		emergency_purchase_system,
		reputation_system,
		settlement_builder,
		day_event_system,
		station_layout_system
	]:
		system.bind(self)

	pending_customers = pending_order_system.pending_customers


func set_spawn_policy(policy: Dictionary) -> void:
	customer_queue_system.set_spawn_policy(policy)


func get_active_queue_snapshot() -> Array:
	return customer_queue_system.get_active_queue_snapshot()


func get_system_debug_report() -> Array[String]:
	var report: Array[String] = []

	for system in [
		business_day_system,
		customer_queue_system,
		pending_order_system,
		order_system,
		inventory_system,
		cooking_system,
		supplier_system,
		emergency_purchase_system,
		reputation_system,
		settlement_builder,
		day_event_system,
		station_layout_system
	]:
		if system == null:
			report.append("A gameplay system failed to initialize.")
			continue

		if system.has_method("debug_validate"):
			var system_report = system.debug_validate()
			for warning in system_report:
				report.append(str(warning))

	return report


func debug_validate_runtime() -> bool:
	var blocking_errors: Array[String] = []
	var warnings: Array[String] = []

	if spawn_timer == null:
		blocking_errors.append("GameManager: SpawnTimer is missing.")

	if characters_node == null:
		blocking_errors.append("GameManager: Characters node is missing.")

	if customer_spawn == null:
		blocking_errors.append("GameManager: CustomerSpawn marker is missing.")

	if queue_spot_1 == null or queue_spot_2 == null or queue_spot_3 == null:
		blocking_errors.append("GameManager: one or more queue spots are missing.")

	if counter_node == null:
		blocking_errors.append("GameManager: Counter station node is missing.")

	if delivery_node == null:
		blocking_errors.append("GameManager: DeliveryPoint station node is missing.")

	if storage_node == null:
		blocking_errors.append("GameManager: StorageArea station node is missing.")

	if cooker_1_node == null:
		blocking_errors.append("GameManager: primary Cooker station node is missing.")

	if emergency_shop_node == null:
		warnings.append("GameManager: EmergencyShop station node is missing.")

	if get_tree().get_first_node_in_group("game_ui") == null:
		warnings.append("GameManager: no node in group game_ui.")

	if get_node_or_null("/root/RunSetupData") == null:
		blocking_errors.append("GameManager: RunSetupData autoload is missing.")
	elif RunSetupData.has_method("debug_validate"):
		for warning in RunSetupData.debug_validate():
			warnings.append(str(warning))

	if get_node_or_null("/root/ProgressData") == null:
		blocking_errors.append("GameManager: ProgressData autoload is missing.")

	if get_node_or_null("/root/TextDB") == null:
		blocking_errors.append("GameManager: TextDB autoload is missing.")

	if get_node_or_null("/root/EffectManager") == null:
		blocking_errors.append("GameManager: EffectManager autoload is missing.")

	if typeof(queued_customers) != TYPE_ARRAY:
		blocking_errors.append("GameManager: queued_customers is not an Array.")

	if typeof(pending_customers) != TYPE_ARRAY:
		blocking_errors.append("GameManager: pending_customers is not an Array.")

	if typeof(raw_stock) != TYPE_DICTIONARY:
		blocking_errors.append("GameManager: raw_stock is not a Dictionary.")

	if typeof(cooked_stock) != TYPE_DICTIONARY:
		blocking_errors.append("GameManager: cooked_stock is not a Dictionary.")

	if typeof(staple_stock) != TYPE_DICTIONARY:
		blocking_errors.append("GameManager: staple_stock is not a Dictionary.")

	for warning in get_system_debug_report():
		warnings.append(warning)

	for warning in warnings:
		push_warning(warning)

	for error in blocking_errors:
		push_error(error)

	return blocking_errors.is_empty()

func _process(delta: float) -> void:
	update_day_timer(delta)
	supplier_system.update(delta)
	cooking_system.update(delta)

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
	for customer in pending_order_system.get_all():
		if customer != null and is_instance_valid(customer):
			if not CustomerOrderState.is_served(customer):
				order_cards.append(get_pending_order_card_data(customer))

	if order_cards.is_empty():
		game_ui.hide_pending_orders()
	else:
		game_ui.show_pending_orders(order_cards)

func update_day_timer(delta: float) -> void:
	business_day_system.update_day_timer(delta)

func force_close_day_before_opening() -> void:
	business_day_system.force_close_day_before_opening()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("round_summary"):
		print_round_summary()

func _apply_upgrade_flags() -> void:
	has_second_cooker = ProgressData.has_second_cooker
	order_panel_upgrade_level = ProgressData.order_panel_upgrade_level
	if cooking_system != null:
		cooking_system.cart_pot_capacity = ProgressData.get_cart_pot_capacity()

	if has_second_cooker:
		unlocked_cooker_slots = 2
	else:
		unlocked_cooker_slots = 1

func start_round() -> void:
	RunSetupData.ensure_starting_money_for_new_run()

	initialize_round_stocks()
	day_event_system.activate_and_apply_current_day_business_event()

	_apply_upgrade_flags()
	initialize_cooker_slots()
	initialize_staple_ladle_slots()
	apply_station_layout_from_run_setup()

	var money_state: Dictionary = RunSetupData.get_money_state()
	money = int(money_state.get("run_money", 0))
	round_income = int(money_state.get("run_total_income", 0))
	round_gross_income = int(money_state.get("run_gross_income", 0))
	round_expense = int(money_state.get("run_total_expense", 0))

	today_income = 0
	today_gross_income = 0
	today_expense = 0

	is_open_for_business = false
	is_round_closing = false
	is_cleanup_phase = false
	has_round_finished = false

	has_opened_for_business_today = false
	supplier_system.clear_day_state()

	day_time_left = day_duration_seconds
	auto_close_triggered = false

	RunSetupData.today_special_customer_results = []
	RunSetupData.generated_night_queue = []
	RunSetupData.today_reputation_delta = 0
	RunSetupData.reset_today_stall_echo_stats()

	RunSetupData.setup_daily_special_customer_plan()

	print("=== å½“å‰å¤©å¼€å§‹ ===")
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
	pending_order_system.clear()

	if spawn_timer != null and is_instance_valid(spawn_timer):
		spawn_timer.stop()

	print("å½“å‰æœªå¼€ä¸šï¼Œä¸ç”Ÿæˆæ™®é€šé¡¾å®¢ã€‚")

	show_pending_morning_info_if_any()
	debug_validate_runtime()

# External compatibility wrappers: station/UI/customer scripts still enter gameplay
# through GameManager while systems own the real state and behavior.
func open_supplier_order_panel() -> void:
	supplier_system.open_panel()

func close_supplier_order_panel() -> void:
	supplier_system.close_panel()

func _on_supplier_order_button_pressed(item_id: String, amount: int = 1) -> void:
	supplier_system.place_order(item_id, amount)


func open_cart_pot_panel() -> void:
	cooking_system.open_cart_pot_panel()

func show_storage_stock_only() -> void:
	var game_ui = get_tree().get_first_node_in_group("game_ui")

	if game_ui == null:
		print("Cannot show storage stock. No game_ui found.")
		return

	var cooked_text: String = get_cooked_stock_text()
	var raw_and_staple_text: String = "%s
%s" % [
		get_raw_stock_text(),
		TextDB.get_text("UI_STAPLE_STOCK_LINE") % get_staple_stock_text()
	]

	game_ui.show_stock(
		cooked_text,
		raw_and_staple_text
	)

	print("Show storage stock only.")
	print("Cooked stock text: ", cooked_text)
	print("Raw / staple stock text: ", raw_and_staple_text)
func interact_with_gift_box() -> void:
	day_event_system.interact_with_gift_box()

func open_day_gift_choice_panel(gift_data: Dictionary) -> void:
	day_event_system.open_day_gift_choice_panel(gift_data)


func close_day_gift_choice_panel() -> void:
	day_event_system.close_day_gift_choice_panel()

func _on_day_gift_option_pressed(option_index: int) -> void:
	day_event_system._on_day_gift_option_pressed(option_index)


func get_day_gift_option_button_text(option_data: Dictionary) -> String:
	return day_event_system.get_day_gift_option_button_text(option_data)

func get_ingredient_display_name(item_id: String) -> String:
	return TextDB.get_item_name(item_id)


func get_items_text(items: Dictionary) -> String:
	var parts: Array[String] = []

	for item_id in items.keys():
		var amount: int = int(items.get(item_id, 0))

		if amount <= 0:
			continue

		parts.append("%s x%d" % [
			get_ingredient_display_name(str(item_id)),
			amount
		])

	if parts.is_empty():
		return TextDB.get_text("UI_ITEM_NONE")

	return TextDB.get_text("UI_LIST_JOIN_COMMA").join(parts)

func get_modified_spawn_timer_wait_time() -> float:
	var multiplier: float = RunSetupData.get_current_day_multiplier(
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
	day_event_system.show_pending_morning_info_if_any()

func _apply_special_customer_plan_to_customer(customer: Node) -> void:
	customer_queue_system.apply_special_customer_plan_to_customer(customer)

func initialize_round_stocks() -> void:
	inventory_system.initialize_round_stocks(planned_raw_stock, planned_cooked_stock, planned_staple_stock)

func get_cart_pot_ingredient_ids() -> Array:
	return cooking_system.get_cart_pot_ingredient_ids()


func get_stock_total(stock: Dictionary) -> int:
	return inventory_system.get_stock_total(stock)


func initialize_staple_ladle_slots() -> void:
	cooking_system.initialize_staple_ladle_slots()


func get_first_pending_customer_waiting_for_main_food(main_food_id: String) -> Node:
	return cooking_system.get_first_pending_customer_waiting_for_main_food(main_food_id)


func has_waiting_main_food_order(main_food_id: String) -> bool:
	return cooking_system.has_waiting_main_food_order(main_food_id)

func interact_with_staple_basket(main_food_id: String) -> void:
	cooking_system.interact_with_staple_basket(main_food_id)


func interact_with_staple_ladle(slot_index: int) -> void:
	cooking_system.interact_with_staple_ladle(slot_index)


func initialize_cooker_slots() -> void:
	cooking_system.initialize_cooker_slots()

func apply_station_layout_from_run_setup() -> void:
	station_layout_system.apply_station_layout_from_run_setup()

func get_queue_positions() -> Array:
	return customer_queue_system.get_queue_positions()

func refresh_queue_positions() -> void:
	customer_queue_system.refresh_queue_positions()

func open_business() -> void:
	if not debug_validate_runtime():
		return

	business_day_system.open_business()

func close_business() -> void:
	business_day_system.close_business()

func can_spawn_customers_now() -> bool:
	return business_day_system.can_spawn_customers_now()

func start_initial_customer_wave() -> void:
	customer_queue_system.start_initial_customer_wave()

func spawn_customer() -> void:
	if not debug_validate_runtime():
		return

	customer_queue_system.spawn_customer()


func record_special_customer_result(customer: Node, result: String) -> void:
	reputation_system.record_special_result(customer, result)

func handle_customer_order_completed(customer: Node) -> void:
	reputation_system.record_served(customer)

func handle_customer_patience_timeout(customer: Node) -> void:
	reputation_system.record_failed(customer, "patience timeout")

func get_counter_customer() -> Node:
	return customer_queue_system.get_counter_customer()

func begin_checkout_for_customer(customer: Node) -> bool:
	return order_system.begin_checkout(customer)

func evaluate_order_before_checkout(customer: Node) -> Dictionary:
	return order_system.evaluate_order_before_checkout(customer)

func customer_can_checkout_now(customer: Node) -> bool:
	return order_system.customer_can_checkout_now(customer)

func get_counter_customer_stock_preview(customer: Node) -> Dictionary:
	return order_system.get_counter_customer_stock_preview(customer)

func confirm_checkout_and_create_order(customer: Node, quoted_price: int = -1) -> Dictionary:
	return order_system.confirm_checkout(customer, quoted_price)

func route_customer_after_payment(customer: Node, evaluation: Dictionary) -> String:
	return order_system.route_after_payment(customer, evaluation)

func refresh_money_and_reputation_ui() -> void:
	var game_ui = get_tree().get_first_node_in_group("game_ui")
	if game_ui:
		game_ui.update_money(money)

func change_shop_reputation(delta: int, reason: String = "") -> void:
	reputation_system.change_shop_reputation(delta, reason)

func is_pending_customer_fully_submitted(customer: Node) -> bool:
	return order_system.is_pending_customer_fully_submitted(customer)

func interact_with_delivery_point() -> void:
	order_system.interact_with_delivery_point()

func complete_delivery_for_customer(customer: Node) -> bool:
	return order_system.complete_delivery(customer)

func build_night_queue_from_today_results() -> Array:
	var queue: Array = [
		{
			"type": "insight",
			"name": TextDB.get_text("UI_NIGHT_CHOICE_INSIGHT"),
			"result": "neutral"
		}
	]

	for entry in RunSetupData.today_special_customer_results:
		var gift_id: String = str(entry.get("gift_id", ""))

		if gift_id != "" and RunSetupData.is_gift_opened(gift_id):
			print("Skip opened special echo at night: ", gift_id)
			continue

		var result_text: String = str(entry.get("result", "neutral"))
		var entry_name: String = str(entry.get("name", TextDB.get_text("UI_FALLBACK_SPECIAL_CUSTOMER")))

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
	return order_system.handle_stock_shortage_for_customer(customer)

func apply_adjusted_order_to_customer(customer: Node, adjusted_order: Dictionary) -> void:
	order_system.apply_adjusted_order_to_customer(customer, adjusted_order)

func reject_customer_before_checkout(customer: Node) -> void:
	order_system.reject_customer_before_checkout(customer)

func get_customer_group(customer: Node) -> String:
	return reputation_system.get_customer_group(customer)

func get_customer_type(customer: Node) -> String:
	return reputation_system.get_customer_type(customer)

func get_reputation_delta_for_customer(customer: Node, event_name: String) -> int:
	return reputation_system.get_delta(customer, event_name)

func resolve_price_reaction(_customer: Node, _quoted_price: int, _true_price: int) -> String:
	# å…ˆç•™æŽ¥å£ï¼šä»¥åŽåœ¨è¿™é‡ŒæŽ¥â€œå¤šæ”¶è´¹ / å°‘æ”¶è´¹ / é¡¾å®¢æ€§æ ¼ / å¡ç‰ŒBuffâ€
	return "accept"

func get_first_customer_needing_emergency_purchase() -> Node:
	return emergency_purchase_system.get_first_customer_needing_purchase()

func get_first_uncooked_pending_customer() -> Node:
	return pending_order_system.get_first_uncooked()

func get_cart_ingredients_needed_from_pot(customer: Node) -> Dictionary:
	return cooking_system.get_cart_ingredients_needed_from_pot(customer)

func get_cart_ingredient_shortage_for_customer(customer: Node) -> Dictionary:
	return cooking_system.get_cart_ingredient_shortage_for_customer(customer)


func try_fulfill_cart_ingredients_for_customer(customer: Node) -> bool:
	return cooking_system.try_fulfill_cart_ingredients_for_customer(customer)


func refresh_cart_ingredients_for_pending_customers() -> void:
	cooking_system.refresh_cart_ingredients_for_pending_customers()

func hand_over_held_staple_to_waiting_customer() -> Node:
	return cooking_system.hand_over_held_staple_to_waiting_customer()

func get_first_deliverable_pending_customer() -> Node:
	return order_system.get_first_deliverable_pending_customer()

func remove_customer_from_queue(customer: Node) -> void:
	customer_queue_system.remove_customer_from_queue(customer)

func remove_customer_from_pending(customer: Node) -> void:
	customer_queue_system.remove_customer_from_pending(customer)

func release_counter_customer(customer: Node) -> void:
	customer_queue_system.release_counter_customer(customer)

func notify_customer_leaving(customer: Node) -> void:
	customer_queue_system.notify_customer_leaving(customer)

func _on_customer_exited(customer: Node) -> void:
	customer_queue_system.on_customer_exited(customer)

func _on_spawn_timer_timeout() -> void:
	customer_queue_system.on_spawn_timer_timeout()

func print_stocks() -> void:
	print("Cooked stock: ", cooked_stock)
	print("Raw stock: ", raw_stock)
	print("Staple stock: ", staple_stock)

func add_pending_customer(customer: Node) -> void:
	remove_customer_from_queue(customer)

	pending_order_system.add(customer)

	if can_spawn_customers_now():
		if queued_customers.size() < max_queue_size:
			spawn_customer()

func has_pending_customer() -> bool:
	return pending_order_system.has_pending()

func is_customer_in_any_cooker(customer: Node) -> bool:
	return cooking_system.is_customer_in_any_cooker(customer)

func find_free_cooker_slot_index() -> int:
	return cooking_system.find_free_cooker_slot_index()

func get_customer_cooker_slot_index(customer: Node) -> int:
	return cooking_system.get_customer_cooker_slot_index(customer)

func remove_customer_from_cooker_slots(customer: Node) -> void:
	cooking_system.remove_customer_from_cooker_slots(customer)

func start_cooking_pending_order() -> void:
	open_cart_pot_panel()


func start_shop_order_bound_cooking_pending_order() -> void:
	cooking_system.start_shop_order_bound_cooking_pending_order()

func can_fulfill_from_cooked(ingredients: Dictionary) -> bool:
	return inventory_system.can_fulfill_from_cooked(ingredients)

func can_fulfill_from_combined_stock(ingredients: Dictionary) -> bool:
	return inventory_system.can_fulfill_from_combined_stock(ingredients)

func get_order_fulfillment_status(ingredients: Dictionary) -> String:
	return inventory_system.get_order_fulfillment_status(ingredients)

func deduct_cooked_stock(ingredients: Dictionary) -> void:
	inventory_system.deduct_cooked_stock(ingredients)

func consume_raw_stock_for_order(ingredients: Dictionary) -> void:
	inventory_system.consume_raw_stock_for_order(ingredients)

func add_cooked_stock_for_order(ingredients: Dictionary) -> void:
	inventory_system.add_cooked_stock_for_order(ingredients)

func get_cooked_stock_text() -> String:
	return inventory_system.get_cooked_stock_text()

func get_raw_stock_text() -> String:
	return inventory_system.get_raw_stock_text()

func get_staple_stock_text() -> String:
	return inventory_system.get_staple_stock_text()

func get_customer_main_food_stock_id(customer: Node) -> String:
	if customer == null or not is_instance_valid(customer):
		return "none"

	if not customer.has_method("get_main_food_id"):
		return "none"

	return str(customer.get_main_food_id())


func customer_has_main_food(customer: Node) -> bool:
	var main_food_id: String = get_customer_main_food_stock_id(customer)

	return main_food_id != "none" and main_food_id != ""


func reserve_main_food_stock_for_customer(customer: Node) -> bool:
	return order_system.reserve_main_food_stock_for_customer(customer)

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
	return emergency_purchase_system.get_total_shortage()


func refresh_all_pending_emergency_purchase_states() -> void:
	emergency_purchase_system.refresh_customer_states()

func get_customer_order_shortage_for_emergency(customer: Node) -> Dictionary:
	return emergency_purchase_system.get_customer_shortage(customer)

func get_order_shortage(ingredients: Dictionary) -> Dictionary:
	return inventory_system.get_order_shortage(ingredients)

func get_emergency_purchase_cost(shortage: Dictionary) -> int:
	return emergency_purchase_system.get_cost(shortage)

func emergency_purchase_for_customer(_customer: Node) -> bool:
	return emergency_purchase_system.purchase_for_waiting_shortages()


func reserve_stock_after_emergency_purchase(customer: Node) -> bool:
	return emergency_purchase_system.reserve_stock_after_purchase(customer)

func get_pending_order_display_text(customer: Node) -> String:
	return order_system.get_pending_order_display_text(customer)

func get_pending_order_remaining_main_food_text(customer: Node) -> String:
	return order_system.get_pending_order_remaining_main_food_text(customer)


func get_pending_order_remaining_ingredients(customer: Node) -> Dictionary:
	return order_system.get_pending_order_remaining_ingredients(customer)


func get_pending_order_remaining_ingredients_text(customer: Node) -> String:
	return order_system.get_pending_order_remaining_ingredients_text(customer)


func get_pending_order_card_status_text(customer: Node) -> String:
	return order_system.get_pending_order_card_status_text(customer)

func get_pending_order_card_data(customer: Node) -> Dictionary:
	return order_system.get_pending_order_card_data(customer)

func get_pending_order_status_id(customer: Node) -> String:
	return order_system.get_pending_order_status_id(customer)

func get_pending_order_delivery_target_text(_customer: Node) -> String:
	return order_system.get_pending_order_delivery_target_text(_customer)

func add_money(amount: int) -> void:
	if amount <= 0:
		return

	money += amount

	today_gross_income += amount
	round_gross_income += amount

	today_income += amount
	round_income += amount
	RunSetupData.set_money_state(money, round_income, round_gross_income, round_expense)

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
	return cooking_system.get_effective_cart_pot_batch_duration()


func get_effective_staple_ladle_duration() -> float:
	return cooking_system.get_effective_staple_ladle_duration()

func change_reputation(delta: int, reason: String = "") -> void:
	reputation_system.change(delta, reason)

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
	RunSetupData.set_money_state(money, round_income, round_gross_income, round_expense)

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
	var waste: int = 0

	for ingredient_name in raw_stock.keys():
		waste += raw_stock[ingredient_name]

	for ingredient_name in cooked_stock.keys():
		waste += cooked_stock[ingredient_name]

	return waste

func get_round_profit() -> int:
	return round_income - get_waste_value()

func print_round_summary() -> void:
	print("=== æœ¬è½®ç»“ç®— ===")
	print("Today income: ", today_income)
	print("Round income: ", round_income)
	print("Waste value: ", get_waste_value())
	print("Round profit: ", get_round_profit())
	print("Current money: ", money)
	print("Remaining cooked stock: ", cooked_stock)
	print("Remaining raw stock: ", raw_stock)

func try_finish_day() -> void:
	business_day_system.try_finish_day()

func can_enter_cleanup_phase() -> bool:
	return business_day_system.can_enter_cleanup_phase()

func has_active_customers_or_orders() -> bool:
	for customer in queued_customers:
		if _customer_blocks_cart_cleanup(customer):
			return true

	for customer in pending_order_system.get_all():
		if _customer_blocks_cart_cleanup(customer):
			return true

	if characters_node != null and is_instance_valid(characters_node):
		for child in characters_node.get_children():
			if _customer_blocks_cart_cleanup(child):
				return true

	var customer_nodes: Array = get_tree().get_nodes_in_group("customers")

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

	# å…œåº•é€»è¾‘ï¼š
	# å¦‚æžœæŸä¸ªé¡¾å®¢è„šæœ¬è¿˜æ²¡æœ‰ blocks_cart_cleanup()ï¼Œ
	# è‡³å°‘ä¸è¦è®©å·²ç»æœåŠ¡å®Œæˆæˆ–å·²ç»å› è€å¿ƒç¦»å¼€çš„é¡¾å®¢é˜»æ­¢æ”¶æ‘Šã€‚
	if CustomerOrderState.is_served(customer):
		return false

	if CustomerOrderState.is_leaving_due_to_patience(customer):
		return false

	return true

func has_busy_cooker() -> bool:
	return cooking_system.has_busy_cooking()


func enter_cleanup_phase() -> void:
	business_day_system.enter_cleanup_phase()

func can_finalize_day_now() -> bool:
	return business_day_system.can_finalize_day_now()

func finish_day_from_cleanup() -> void:
	business_day_system.finish_day_from_cleanup()

func can_finish_day_now() -> bool:
	if has_busy_cooker():
		return false

	var customers = get_tree().get_nodes_in_group("customers")
	for customer in customers:
		if customer != null and is_instance_valid(customer):
			return false

	return true

func clear_staple_ladle_and_held_food_at_day_end() -> Dictionary:
	return cooking_system.clear_day_end_state()

func finish_day() -> void:
	has_round_finished = true

	var remaining_cooked_stock: Dictionary = cooked_stock.duplicate(true)
	var remaining_raw_stock: Dictionary = raw_stock.duplicate(true)
	var remaining_staple_stock: Dictionary = staple_stock.duplicate(true)
	var discarded_staple_food: Dictionary = clear_staple_ladle_and_held_food_at_day_end()

	# ç†Ÿé£Ÿä¸éš”å¤œï¼šæ—¥ç»“æ˜¾ç¤ºå‰©ä½™ç†Ÿé£Ÿï¼Œä½†ä¸‹ä¸€å¤©ä¸ç»§æ‰¿ç†Ÿé£Ÿã€‚
	RunSetupData.set_money_state(money, round_income, round_gross_income, round_expense)
	RunSetupData.set_stock_state(remaining_raw_stock, get_zero_food_stock(), remaining_staple_stock)

	RunSetupData.generated_night_queue = build_night_queue_from_today_results()

	var day_summary: Dictionary = settlement_builder.build_day_summary(_build_settlement_summary_input(
		remaining_cooked_stock,
		remaining_raw_stock,
		remaining_staple_stock,
		discarded_staple_food
	))

	RunSetupData.set_day_summary(day_summary)

	if RunSetupData.current_day_in_run >= RunSetupData.total_days_in_run:
		finish_run()
		return

	print("=== ç¬¬ %d å¤©ç»“æŸ ===" % RunSetupData.current_day_in_run)
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

	get_tree().call_deferred("change_scene_to_file", "res://scenes/settlement/settlement_result.tscn")

func finish_run() -> void:
	var remaining_cooked_stock: Dictionary = cooked_stock.duplicate(true)
	var remaining_raw_stock: Dictionary = raw_stock.duplicate(true)
	var remaining_staple_stock: Dictionary = staple_stock.duplicate(true)

	RunSetupData.set_money_state(money, round_income, round_gross_income, round_expense)
	RunSetupData.set_stock_state(remaining_raw_stock, get_zero_food_stock(), remaining_staple_stock)

	var run_summary: Dictionary = settlement_builder.build_run_summary(_build_settlement_summary_input(
		remaining_cooked_stock,
		remaining_raw_stock,
		remaining_staple_stock,
		{}
	))

	RunSetupData.set_run_summary(run_summary)

	print("=== æœ¬è½®ç»“ç®— ===")
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

	get_tree().call_deferred("change_scene_to_file", "res://scenes/settlement/settlement_result.tscn")


func _build_settlement_summary_input(
	remaining_cooked_stock: Dictionary,
	remaining_raw_stock: Dictionary,
	remaining_staple_stock: Dictionary,
	discarded_staple_food: Dictionary
) -> Dictionary:
	return {
		"today_gross_income": today_gross_income,
		"today_expense": today_expense,
		"today_net_income": today_income,
		"run_gross_income": round_gross_income,
		"run_expense": round_expense,
		"run_net_income": round_income,
		"current_money": money,
		"cooked_stock_text": get_cooked_stock_text(),
		"raw_stock_text": "%s
%s" % [
			get_raw_stock_text(),
			TextDB.get_text("UI_STAPLE_STOCK_LINE") % get_staple_stock_text()
		],
		"cooked_stock_data": remaining_cooked_stock,
		"raw_stock_data": remaining_raw_stock,
		"staple_stock_data": remaining_staple_stock,
		"discarded_staple_food": discarded_staple_food
	}
