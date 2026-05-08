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
const EconomySystemScript = preload("res://gameplay/systems/economy_system.gd")
const GameplayHudSystemScript = preload("res://gameplay/systems/gameplay_hud_system.gd")
const StationInteractionSystemScript = preload("res://gameplay/systems/station_interaction_system.gd")
const NightQueueBuilderScript = preload("res://gameplay/systems/night_queue_builder.gd")

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
var economy_system: EconomySystem
var gameplay_hud_system: GameplayHudSystem
var station_interaction_system: StationInteractionSystem
var night_queue_builder: NightQueueBuilder

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

var day_duration_seconds: float = 5.0
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

# 多锅系统
var total_cooker_slots: int = 2
var unlocked_cooker_slots: int = 1
var cooker_duration: float = 3.0

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
	economy_system = EconomySystemScript.new()
	gameplay_hud_system = GameplayHudSystemScript.new()
	station_interaction_system = StationInteractionSystemScript.new()
	night_queue_builder = NightQueueBuilderScript.new()

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
		station_layout_system,
		economy_system,
		gameplay_hud_system,
		station_interaction_system,
		night_queue_builder
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
		station_layout_system,
		economy_system,
		gameplay_hud_system,
		station_interaction_system,
		night_queue_builder
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

	gameplay_hud_system.update()

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

	economy_system.load_run_state()

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

	print("=== Current day started ===")
	print("Day: ", RunSetupData.current_day_in_run, "/", RunSetupData.total_days_in_run)
	print("Selected stage id: ", RunSetupData.selected_stage_id)
	print("Selected difficulty days: ", RunSetupData.selected_difficulty_days)
	print("Station layout from RunSetupData: ", RunSetupData.station_layout)
	print("Current day business event: ", RunSetupData.current_day_business_event)
	print("Starting / current money: ", money)
	inventory_system.print_stocks()

	gameplay_hud_system.reset_for_new_day()

	queued_customers.clear()
	pending_order_system.clear()

	if spawn_timer != null and is_instance_valid(spawn_timer):
		spawn_timer.stop()

	print("Not opened yet. Normal customers will not spawn.")

	show_pending_morning_info_if_any()
	debug_validate_runtime()

func get_ingredient_display_name(item_id: String) -> String:
	return TextDB.get_item_name(item_id)


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
	gameplay_hud_system.refresh_money_and_reputation_ui()

func change_shop_reputation(delta: int, reason: String = "") -> void:
	reputation_system.change_shop_reputation(delta, reason)

func is_pending_customer_fully_submitted(customer: Node) -> bool:
	return order_system.is_pending_customer_fully_submitted(customer)

func interact_with_delivery_point() -> void:
	order_system.interact_with_delivery_point()

func complete_delivery_for_customer(customer: Node) -> bool:
	return order_system.complete_delivery(customer)

func get_customer_group(customer: Node) -> String:
	return reputation_system.get_customer_group(customer)

func get_customer_type(customer: Node) -> String:
	return reputation_system.get_customer_type(customer)

func get_reputation_delta_for_customer(customer: Node, event_name: String) -> int:
	return reputation_system.get_delta(customer, event_name)

func resolve_price_reaction(_customer: Node, _quoted_price: int, _true_price: int) -> String:
	# Ã¥â€¦Ë†Ã§â€¢â„¢Ã¦Å½Â¥Ã¥ÂÂ£Ã¯Â¼Å¡Ã¤Â»Â¥Ã¥ÂÅ½Ã¥Å“Â¨Ã¨Â¿â„¢Ã©â€¡Å’Ã¦Å½Â¥Ã¢â‚¬Å“Ã¥Â¤Å¡Ã¦â€Â¶Ã¨Â´Â¹ / Ã¥Â°â€˜Ã¦â€Â¶Ã¨Â´Â¹ / Ã©Â¡Â¾Ã¥Â®Â¢Ã¦â‚¬Â§Ã¦Â Â¼ / Ã¥ÂÂ¡Ã§â€°Å’BuffÃ¢â‚¬Â
	return "accept"

func get_first_customer_needing_emergency_purchase() -> Node:
	return emergency_purchase_system.get_first_customer_needing_purchase()

func get_first_uncooked_pending_customer() -> Node:
	return pending_order_system.get_first_uncooked()

func refresh_cart_ingredients_for_pending_customers() -> void:
	cooking_system.refresh_cart_ingredients_for_pending_customers()

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

func add_pending_customer(customer: Node) -> void:
	remove_customer_from_queue(customer)

	pending_order_system.add(customer)

	if can_spawn_customers_now():
		if queued_customers.size() < max_queue_size:
			spawn_customer()

func has_pending_customer() -> bool:
	return pending_order_system.has_pending()

func start_cooking_pending_order() -> void:
	cooking_system.open_cart_pot_panel()


func start_shop_order_bound_cooking_pending_order() -> void:
	cooking_system.start_shop_order_bound_cooking_pending_order()

func reserve_main_food_stock_for_customer(customer: Node) -> bool:
	return order_system.reserve_main_food_stock_for_customer(customer)

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

func get_pending_order_status_id(customer: Node) -> String:
	return order_system.get_pending_order_status_id(customer)

func get_pending_order_delivery_target_text(_customer: Node) -> String:
	return order_system.get_pending_order_delivery_target_text(_customer)

func get_effective_cart_pot_batch_duration() -> float:
	return cooking_system.get_effective_cart_pot_batch_duration()


func get_effective_staple_ladle_duration() -> float:
	return cooking_system.get_effective_staple_ladle_duration()

func change_reputation(delta: int, reason: String = "") -> void:
	reputation_system.change(delta, reason)

func print_round_summary() -> void:
	economy_system.print_round_summary()

func try_finish_day() -> void:
	business_day_system.try_finish_day()

func can_enter_cleanup_phase() -> bool:
	return business_day_system.can_enter_cleanup_phase()

func has_active_customers_or_orders() -> bool:
	return business_day_system.has_active_customers_or_orders()
func has_busy_cooker() -> bool:
	return business_day_system.has_busy_cooker()


func enter_cleanup_phase() -> void:
	business_day_system.enter_cleanup_phase()

func can_finalize_day_now() -> bool:
	return business_day_system.can_finalize_day_now()

func finish_day_from_cleanup() -> void:
	business_day_system.finish_day_from_cleanup()

func can_finish_day_now() -> bool:
	return business_day_system.can_finish_day_now()

func clear_staple_ladle_and_held_food_at_day_end() -> Dictionary:
	return cooking_system.clear_day_end_state()

func finish_day() -> void:
	has_round_finished = true

	var remaining_cooked_stock: Dictionary = cooked_stock.duplicate(true)
	var remaining_raw_stock: Dictionary = raw_stock.duplicate(true)
	var remaining_staple_stock: Dictionary = staple_stock.duplicate(true)
	var discarded_staple_food: Dictionary = clear_staple_ladle_and_held_food_at_day_end()

	# Cooked food does not carry over overnight.
	# The day settlement shows remaining cooked food, but the next day starts with zero cooked stock.
	RunSetupData.set_money_state(money, round_income, round_gross_income, round_expense)
	RunSetupData.set_stock_state(remaining_raw_stock, inventory_system.get_zero_food_stock(), remaining_staple_stock)

	RunSetupData.generated_night_queue = night_queue_builder.build_from_today_results()

	var day_summary: Dictionary = settlement_builder.build_day_summary(_build_settlement_summary_input(
		remaining_cooked_stock,
		remaining_raw_stock,
		remaining_staple_stock,
		discarded_staple_food
	))

	RunSetupData.set_day_summary(day_summary)

	print("=== Day %d ended ===" % RunSetupData.current_day_in_run)
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
	RunSetupData.set_stock_state(remaining_raw_stock, inventory_system.get_zero_food_stock(), remaining_staple_stock)

	var run_summary: Dictionary = settlement_builder.build_run_summary(_build_settlement_summary_input(
		remaining_cooked_stock,
		remaining_raw_stock,
		remaining_staple_stock,
		{}
	))

	RunSetupData.set_run_summary(run_summary)

	print("=== Run Summary ===")
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
	var input: Dictionary = economy_system.get_summary_input_fields()
	input["cooked_stock_text"] = inventory_system.get_cooked_stock_text()
	input["raw_stock_text"] = "%s
%s" % [
		inventory_system.get_raw_stock_text(),
		TextDB.get_text("UI_STAPLE_STOCK_LINE") % inventory_system.get_staple_stock_text()
	]
	input["cooked_stock_data"] = remaining_cooked_stock
	input["raw_stock_data"] = remaining_raw_stock
	input["staple_stock_data"] = remaining_staple_stock
	input["discarded_staple_food"] = discarded_staple_food
	return input
