extends Node

const ItemIds = preload("res://gameplay/models/item_ids.gd")
const RunEchoStateScript = preload("res://gameplay/models/run_echo_state.gd")
const RunSettlementStateScript = preload("res://gameplay/models/run_settlement_state.gd")
const RunRuntimeStateScript = preload("res://gameplay/models/run_runtime_state.gd")
const RunConfigStateScript = preload("res://gameplay/models/run_config_state.gd")
const RunDayEventStateScript = preload("res://gameplay/models/run_day_event_state.gd")

const RUN_MODE_TUTORIAL: String = "tutorial"
const RUN_MODE_NORMAL: String = "normal"

var run_mode: String = RUN_MODE_NORMAL
var selected_stage_id: String = ""
var selected_difficulty_days: int = 7

var station_layout: Dictionary = {
	"counter": "",
	"delivery": "",
	"storage": "",
	"cooker_1": "",
	"cooker_2": "",
	"emergency_shop": ""
}


var run_modifiers: Dictionary = {
	"allow_pre_open_waiting_customers": false,
	"lock_station_layout": false
}

var current_day_in_run: int = 1
var total_days_in_run: int = 7

var run_money: int = 0
var run_total_income: int = 0
var run_gross_income: int = 0
var run_total_expense: int = 0

var current_raw_stock: Dictionary = {}
var current_cooked_stock: Dictionary = {}

var starting_money: int = 70
var supplier_delivery_seconds: float = 6.0

var basic_ingredient_ids: Array[String] = [
	ItemIds.SPINACH,
	ItemIds.POTATO_SLICE,
	ItemIds.TOFU_PUFF
]

var staple_item_ids: Array[String] = [
	ItemIds.GLASS_NOODLE,
	ItemIds.NOODLE
]

var supplier_base_prices: Dictionary = {
	"spinach": 1,
	"potato_slice": 1,
	"tofu_puff": 2,
	"glass_noodle": 0.5,
	"noodle": 0.5
}

var supplier_package_options: Array = [
	{
		"id": "basket",
		"text_key": "UI_SUPPLIER_PACKAGE_BASKET",
		"amount": 10
	},
	{
		"id": "box",
		"text_key": "UI_SUPPLIER_PACKAGE_BOX",
		"amount": 30
	}
]

var neighbor_emergency_price_multiplier: float = 3.0

var current_staple_stock: Dictionary = {}

var current_day_special_spawn_plan: Array = []
var today_special_customer_results: Array = []
var generated_night_queue: Array = []

# 特殊客人留下、但还没有打开的礼物
var pending_gifts: Array = []

# 已打开礼物记录，后面接礼物抽卡时会用
var opened_gifts: Array = []

# 用于稳定记录礼物获得顺序
var gift_sequence_id: int = 0

var active_effects: Array = []

# 店铺口碑，范围 0~100
var shop_reputation: int = 50

# 当天口碑变化，只用于日结显示
var today_reputation_delta: int = 0

var today_customers_served: int = 0
var today_customers_failed: int = 0
var today_special_echo_records: Array = []

var settlement_view_mode: String = "day"
var last_day_summary: Dictionary = {}
var last_run_summary: Dictionary = {}
var current_night_activity: Dictionary = {}
var pending_morning_info: Dictionary = {}

var pending_tomorrow_event: Dictionary = {}
var current_day_business_event: Dictionary = {}
var current_day_modifiers: Dictionary = {}

var echo_state: RunEchoState
var settlement_state: RunSettlementState
var runtime_state: RunRuntimeState
var config_state: RunConfigState
var day_event_state: RunDayEventState


func _ready() -> void:
	_ensure_echo_state()
	_ensure_settlement_state()
	_ensure_runtime_state()
	_ensure_config_state()
	_ensure_day_event_state()


func _ensure_echo_state() -> void:
	if echo_state == null:
		echo_state = RunEchoStateScript.new()


func _ensure_settlement_state() -> void:
	if settlement_state == null:
		settlement_state = RunSettlementStateScript.new()


func _ensure_runtime_state() -> void:
	if runtime_state == null:
		runtime_state = RunRuntimeStateScript.new()


func _ensure_config_state() -> void:
	if config_state == null:
		config_state = RunConfigStateScript.new()
		config_state.bind(self)


func _ensure_day_event_state() -> void:
	if day_event_state == null:
		day_event_state = RunDayEventStateScript.new()
		day_event_state.bind(self)


func _sync_echo_fields_from_state() -> void:
	_ensure_echo_state()
	pending_gifts = echo_state.pending_gifts
	opened_gifts = echo_state.opened_gifts
	gift_sequence_id = echo_state.gift_sequence_id
	today_customers_served = echo_state.today_customers_served
	today_customers_failed = echo_state.today_customers_failed
	today_special_echo_records = echo_state.today_special_echo_records


func _sync_echo_state_from_fields() -> void:
	_ensure_echo_state()
	echo_state.pending_gifts = pending_gifts
	echo_state.opened_gifts = opened_gifts
	echo_state.gift_sequence_id = gift_sequence_id
	echo_state.today_customers_served = today_customers_served
	echo_state.today_customers_failed = today_customers_failed
	echo_state.today_special_echo_records = today_special_echo_records


func debug_validate() -> Array[String]:
	_sync_echo_state_from_fields()
	_sync_settlement_state_from_fields()
	_sync_runtime_state_from_fields()
	_ensure_config_state()
	_ensure_day_event_state()
	var warnings: Array[String] = echo_state.debug_validate()
	for warning in settlement_state.debug_validate():
		warnings.append(str(warning))
	for warning in runtime_state.debug_validate():
		warnings.append(str(warning))
	for warning in config_state.debug_validate():
		warnings.append(str(warning))
	for warning in day_event_state.debug_validate():
		warnings.append(str(warning))
	return warnings


func _sync_settlement_fields_from_state() -> void:
	_ensure_settlement_state()
	settlement_view_mode = settlement_state.settlement_view_mode
	last_day_summary = settlement_state.last_day_summary
	last_run_summary = settlement_state.last_run_summary


func _sync_settlement_state_from_fields() -> void:
	_ensure_settlement_state()
	settlement_state.settlement_view_mode = settlement_view_mode
	settlement_state.last_day_summary = last_day_summary
	settlement_state.last_run_summary = last_run_summary


func set_day_summary(summary: Dictionary) -> void:
	_sync_settlement_state_from_fields()
	settlement_state.set_day_summary(summary)
	_sync_settlement_fields_from_state()


func set_run_summary(summary: Dictionary) -> void:
	_sync_settlement_state_from_fields()
	settlement_state.set_run_summary(summary)
	_sync_settlement_fields_from_state()


func get_day_summary() -> Dictionary:
	_sync_settlement_state_from_fields()
	return settlement_state.last_day_summary.duplicate(true)


func get_run_summary() -> Dictionary:
	_sync_settlement_state_from_fields()
	return settlement_state.last_run_summary.duplicate(true)


func get_settlement_view_mode() -> String:
	_sync_settlement_state_from_fields()
	return settlement_state.settlement_view_mode


func _sync_runtime_fields_from_state() -> void:
	_ensure_runtime_state()
	run_money = runtime_state.run_money
	run_total_income = runtime_state.run_total_income
	run_gross_income = runtime_state.run_gross_income
	run_total_expense = runtime_state.run_total_expense
	current_raw_stock = runtime_state.current_raw_stock
	current_cooked_stock = runtime_state.current_cooked_stock
	current_staple_stock = runtime_state.current_staple_stock


func _sync_runtime_state_from_fields() -> void:
	_ensure_runtime_state()
	runtime_state.run_money = run_money
	runtime_state.run_total_income = run_total_income
	runtime_state.run_gross_income = run_gross_income
	runtime_state.run_total_expense = run_total_expense
	runtime_state.current_raw_stock = current_raw_stock
	runtime_state.current_cooked_stock = current_cooked_stock
	runtime_state.current_staple_stock = current_staple_stock


func set_money_state(money: int, total_income: int, gross_income: int, total_expense: int) -> void:
	_sync_runtime_state_from_fields()
	runtime_state.set_money_state(money, total_income, gross_income, total_expense)
	_sync_runtime_fields_from_state()


func get_money_state() -> Dictionary:
	_sync_runtime_state_from_fields()
	return runtime_state.get_money_state()


func set_stock_state(raw_stock: Dictionary, cooked_stock: Dictionary, staple_stock: Dictionary) -> void:
	_sync_runtime_state_from_fields()
	runtime_state.set_stock_state(raw_stock, cooked_stock, staple_stock)
	_sync_runtime_fields_from_state()


func get_stock_state() -> Dictionary:
	_sync_runtime_state_from_fields()
	return runtime_state.get_stock_state()


func reset_runtime_state() -> void:
	_ensure_runtime_state()
	runtime_state.reset()
	_sync_runtime_fields_from_state()


func reset_run_setup() -> void:
	_ensure_echo_state()
	_ensure_settlement_state()
	_ensure_runtime_state()
	run_mode = RUN_MODE_NORMAL
	selected_stage_id = ""
	selected_difficulty_days = 7

	station_layout = {
		"counter": "",
		"delivery": "",
		"storage": "",
		"cooker_1": "",
		"cooker_2": "",
		"emergency_shop": ""
	}

	run_modifiers = {
		"allow_pre_open_waiting_customers": false,
		"lock_station_layout": false
	}

	current_day_in_run = 1
	total_days_in_run = 7

	reset_runtime_state()

	current_day_special_spawn_plan = []
	today_special_customer_results = []
	generated_night_queue = []

	echo_state.reset_run_state()
	_sync_echo_fields_from_state()

	active_effects = []

	shop_reputation = 50
	today_reputation_delta = 0

	settlement_view_mode = "day"
	last_day_summary = {}
	last_run_summary = {}
	settlement_state.reset()
	_sync_settlement_fields_from_state()

	current_night_activity = {}
	pending_morning_info = {}
	pending_tomorrow_event = {}
	current_day_business_event = {}
	current_day_modifiers = {}


func setup_stage_run(stage_id: String, difficulty_days: int = 7) -> void:
	_ensure_config_state()
	config_state.setup_stage_run(stage_id, difficulty_days, RUN_MODE_NORMAL)


func setup_tutorial_run(stage_id: String = "stage_1", difficulty_days: int = 3) -> void:
	_ensure_config_state()
	config_state.setup_stage_run(stage_id, difficulty_days, RUN_MODE_TUTORIAL)


func set_run_mode(mode: String) -> void:
	if mode == RUN_MODE_TUTORIAL:
		run_mode = RUN_MODE_TUTORIAL
	else:
		run_mode = RUN_MODE_NORMAL


func is_tutorial_mode() -> bool:
	return run_mode == RUN_MODE_TUTORIAL


func is_normal_mode() -> bool:
	return run_mode == RUN_MODE_NORMAL


func is_tutorial_day_1() -> bool:
	return is_tutorial_mode() and current_day_in_run == 1


func is_tutorial_day_2() -> bool:
	return is_tutorial_mode() and current_day_in_run == 2


func is_tutorial_day_3() -> bool:
	return is_tutorial_mode() and current_day_in_run == 3


func is_tutorial_day() -> bool:
	return is_tutorial_day_1()


func is_special_customer_tutorial_day() -> bool:
	return is_tutorial_day_2()


func get_tutorial_customer_plan_for_current_day() -> Array:
	return get_tutorial_customer_plan_for_day(current_day_in_run)


func get_tutorial_customer_plan_for_day(day_index: int) -> Array:
	if not is_tutorial_mode():
		return []

	match day_index:
		1:
			return [
				{
					"main_food_id": ItemIds.GLASS_NOODLE,
					"ingredients": {
						ItemIds.SPINACH: 1,
						ItemIds.POTATO_SLICE: 1
					}
				},
				{
					"main_food_id": ItemIds.NOODLE,
					"ingredients": {
						ItemIds.TOFU_PUFF: 1
					}
				},
				{
					"main_food_id": ItemIds.NONE,
					"ingredients": {
						ItemIds.SPINACH: 1,
						ItemIds.TOFU_PUFF: 1
					}
				}
			]
		2:
			return [
				{
					"main_food_id": ItemIds.GLASS_NOODLE,
					"ingredients": {
						ItemIds.POTATO_SLICE: 1,
						ItemIds.TOFU_PUFF: 1
					}
				},
				{
					"main_food_id": ItemIds.NONE,
					"ingredients": {
						ItemIds.SPINACH: 1,
						ItemIds.POTATO_SLICE: 1
					}
				}
			]
		3:
			return [
				{
					"main_food_id": ItemIds.NONE,
					"ingredients": {
						ItemIds.SPINACH: 1
					}
				},
				{
					"main_food_id": ItemIds.GLASS_NOODLE,
					"ingredients": {
						ItemIds.POTATO_SLICE: 1
					}
				},
				{
					"main_food_id": ItemIds.NOODLE,
					"ingredients": {
						ItemIds.TOFU_PUFF: 1
					}
				}
			]
		_:
			return []


func get_tutorial_customer_spawn_interval_seconds() -> float:
	if is_tutorial_day_3():
		return 1.2

	return 1.5


func get_tutorial_customer_count_for_current_day() -> int:
	return get_tutorial_customer_plan_for_current_day().size()


func _apply_default_station_layout() -> void:
	_ensure_config_state()
	config_state.apply_default_station_layout()


func setup_daily_special_customer_plan() -> void:
	_ensure_day_event_state()
	day_event_state.setup_daily_special_customer_plan()

func add_pending_gift(source_type: String, source_name: String, result: String) -> Dictionary:
	_sync_echo_state_from_fields()
	var gift_data: Dictionary = echo_state.add_pending_gift(source_type, source_name, result, current_day_in_run)
	_sync_echo_fields_from_state()

	print("Special customer echo added: ", gift_data)

	return gift_data

func get_pending_gift_index_by_id(gift_id: String) -> int:
	_sync_echo_state_from_fields()
	return echo_state.get_pending_gift_index_by_id(gift_id)


func get_unopened_gift_by_id(gift_id: String) -> Dictionary:
	_sync_echo_state_from_fields()
	return echo_state.get_unopened_gift_by_id(gift_id)


func is_gift_opened(gift_id: String) -> bool:
	_sync_echo_state_from_fields()
	return echo_state.is_gift_opened(gift_id)


func get_gift_current_options(gift_id: String) -> Array:
	_sync_echo_state_from_fields()
	return echo_state.get_gift_current_options(gift_id)


func set_gift_current_options(gift_id: String, options: Array) -> void:
	_sync_echo_state_from_fields()
	echo_state.set_gift_current_options(gift_id, options)
	_sync_echo_fields_from_state()


func mark_gift_opened(gift_id: String, chosen_card: Dictionary) -> Dictionary:
	_sync_echo_state_from_fields()
	var gift_data: Dictionary = echo_state.mark_gift_opened(gift_id, chosen_card, current_day_in_run)
	_sync_echo_fields_from_state()

	print("Special customer echo opened: ", gift_data)

	return gift_data.duplicate(true)

func get_unopened_pending_gifts() -> Array:
	_sync_echo_state_from_fields()
	return echo_state.get_unopened_pending_gifts()


func has_unopened_pending_gifts() -> bool:
	return not get_unopened_pending_gifts().is_empty()


func get_pending_gift_lines() -> Array[String]:
	_sync_echo_state_from_fields()
	return echo_state.get_pending_gift_lines()

func reset_today_stall_echo_stats() -> void:
	_sync_echo_state_from_fields()
	echo_state.reset_today_stats()
	_sync_echo_fields_from_state()


func record_today_served_customer() -> void:
	_sync_echo_state_from_fields()
	echo_state.record_today_served_customer()
	_sync_echo_fields_from_state()


func record_today_failed_customer() -> void:
	_sync_echo_state_from_fields()
	echo_state.record_today_failed_customer()
	_sync_echo_fields_from_state()


func record_today_special_echo(display_name: String, result: String) -> void:
	_sync_echo_state_from_fields()
	echo_state.record_today_special_echo(display_name, result)
	_sync_echo_fields_from_state()


func get_today_stall_echo_lines() -> Array[String]:
	_sync_echo_state_from_fields()
	return echo_state.get_today_stall_echo_lines()

func generate_night_background_activity(has_next_day: bool = true) -> Dictionary:
	_ensure_day_event_state()
	return day_event_state.generate_night_background_activity(has_next_day)


func generate_tomorrow_business_event_for_activity(activity_id: String) -> Dictionary:
	_ensure_day_event_state()
	return day_event_state.generate_tomorrow_business_event_for_activity(activity_id)

func make_tomorrow_business_event(
	event_id: String,
	title: String,
	text: String,
	tone: String,
	modifiers: Dictionary
) -> Dictionary:
	_ensure_day_event_state()
	return day_event_state.make_tomorrow_business_event(event_id, title, text, tone, modifiers)

func activate_pending_tomorrow_event() -> Dictionary:
	_ensure_day_event_state()
	return day_event_state.activate_pending_tomorrow_event()

func get_current_day_multiplier(modifier_id: String, default_value: float = 1.0) -> float:
	_ensure_day_event_state()
	return day_event_state.get_current_day_multiplier(modifier_id, default_value)


func get_current_day_additive(modifier_id: String, default_value: float = 0.0) -> float:
	_ensure_day_event_state()
	return day_event_state.get_current_day_additive(modifier_id, default_value)

func get_current_night_activity_text() -> String:
	_ensure_day_event_state()
	return day_event_state.get_current_night_activity_text()

func has_pending_morning_info() -> bool:
	_ensure_day_event_state()
	return day_event_state.has_pending_morning_info()

func consume_pending_morning_info_lines() -> Array[String]:
	_ensure_day_event_state()
	return day_event_state.consume_pending_morning_info_lines()

func get_basic_ingredient_ids() -> Array[String]:
	_ensure_config_state()
	return config_state.get_basic_ingredient_ids()


func get_staple_item_ids() -> Array[String]:
	_ensure_config_state()
	return config_state.get_staple_item_ids()


func get_supplier_order_item_ids() -> Array[String]:
	_ensure_config_state()
	return config_state.get_supplier_order_item_ids()


func get_supplier_package_options() -> Array:
	_ensure_config_state()
	return config_state.get_supplier_package_options()


func is_staple_item(item_id: String) -> bool:
	_ensure_config_state()
	return config_state.is_staple_item(item_id)


func get_supplier_delivery_seconds() -> float:
	_ensure_config_state()
	return config_state.get_supplier_delivery_seconds()


func get_supplier_base_price(item_id: String) -> float:
	_ensure_config_state()
	return config_state.get_supplier_base_price(item_id)


func get_supplier_order_price(item_id: String, amount: int = 1) -> int:
	_ensure_config_state()
	return config_state.get_supplier_order_price(item_id, amount)


func get_supplier_order_price_for_items(items: Dictionary) -> int:
	_ensure_config_state()
	return config_state.get_supplier_order_price_for_items(items)


func get_neighbor_emergency_price(item_id: String, amount: int = 1) -> int:
	_ensure_config_state()
	return config_state.get_neighbor_emergency_price(item_id, amount)


func get_neighbor_emergency_price_for_shortage(shortage: Dictionary) -> int:
	_ensure_config_state()
	return config_state.get_neighbor_emergency_price_for_shortage(shortage)



func ensure_starting_money_for_new_run() -> void:
	_ensure_config_state()
	config_state.ensure_starting_money_for_new_run()
