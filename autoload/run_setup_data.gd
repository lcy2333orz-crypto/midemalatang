extends Node

const ItemIds = preload("res://gameplay/models/item_ids.gd")
const RunEchoStateScript = preload("res://gameplay/models/run_echo_state.gd")
const RunSettlementStateScript = preload("res://gameplay/models/run_settlement_state.gd")
const RunRuntimeStateScript = preload("res://gameplay/models/run_runtime_state.gd")

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


func _ready() -> void:
	_ensure_echo_state()
	_ensure_settlement_state()
	_ensure_runtime_state()


func _ensure_echo_state() -> void:
	if echo_state == null:
		echo_state = RunEchoStateScript.new()


func _ensure_settlement_state() -> void:
	if settlement_state == null:
		settlement_state = RunSettlementStateScript.new()


func _ensure_runtime_state() -> void:
	if runtime_state == null:
		runtime_state = RunRuntimeStateScript.new()


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
	var warnings: Array[String] = echo_state.debug_validate()
	for warning in settlement_state.debug_validate():
		warnings.append(str(warning))
	for warning in runtime_state.debug_validate():
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
	reset_run_setup()

	selected_stage_id = stage_id
	selected_difficulty_days = difficulty_days
	current_day_in_run = 1
	total_days_in_run = difficulty_days

	_apply_default_station_layout()


func _apply_default_station_layout() -> void:
	station_layout["counter"] = "slot_a"
	station_layout["cooker_1"] = "slot_b"
	station_layout["delivery"] = "slot_c"
	station_layout["storage"] = "slot_e"

	if ProgressData.has_second_cooker:
		station_layout["cooker_2"] = "slot_d"
		station_layout["emergency_shop"] = "slot_f"
	else:
		station_layout["cooker_2"] = ""
		station_layout["emergency_shop"] = "slot_f"


func setup_daily_special_customer_plan() -> void:
	current_day_special_spawn_plan = [
		{
			"type": "mouse",
			"name": TextDB.get_text("UI_SPECIAL_CUSTOMER_MOUSE")
		}
	]

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
	var options: Array = []

	if has_next_day:
		options = [
			_make_night_activity("reading_notes", "UI_NIGHT_ACTIVITY_READING_NOTES", "UI_MORNING_TITLE_READING_NOTES", "UI_MORNING_TEXT_READING_NOTES"),
			_make_night_activity("chatting_neighbor", "UI_NIGHT_ACTIVITY_CHATTING_NEIGHBOR", "UI_MORNING_TITLE_CHATTING_NEIGHBOR", "UI_MORNING_TEXT_CHATTING_NEIGHBOR"),
			_make_night_activity("checking_notice", "UI_NIGHT_ACTIVITY_CHECKING_NOTICE", "UI_MORNING_TITLE_CHECKING_NOTICE", "UI_MORNING_TEXT_CHECKING_NOTICE"),
			_make_night_activity("sorting_ingredients", "UI_NIGHT_ACTIVITY_SORTING_INGREDIENTS", "UI_MORNING_TITLE_SORTING_INGREDIENTS", "UI_MORNING_TEXT_SORTING_INGREDIENTS"),
			_make_night_activity("resting_cart", "UI_NIGHT_ACTIVITY_RESTING_CART", "UI_MORNING_TITLE_RESTING_CART", "UI_MORNING_TEXT_RESTING_CART")
		]
	else:
		options = [
			_make_night_activity("final_rest", "UI_NIGHT_ACTIVITY_FINAL_REST", "", "")
		]

	var chosen: Dictionary = options[randi() % options.size()]
	current_night_activity = chosen.duplicate(true)

	if has_next_day:
		pending_tomorrow_event = generate_tomorrow_business_event_for_activity(str(chosen.get("id", "")))

		pending_morning_info = {
			"title": str(chosen.get("morning_title", "")),
			"text": str(chosen.get("morning_text", "")),
			"source_activity_id": str(chosen.get("id", "")),
			"event": pending_tomorrow_event.duplicate(true)
		}
	else:
		pending_tomorrow_event = {}
		pending_morning_info = {}

	return current_night_activity.duplicate(true)


func _make_night_activity(activity_id: String, activity_key: String, morning_title_key: String, morning_text_key: String) -> Dictionary:
	var morning_title: String = ""
	var morning_text: String = ""

	if morning_title_key != "":
		morning_title = TextDB.get_text(morning_title_key)

	if morning_text_key != "":
		morning_text = TextDB.get_text(morning_text_key)

	return {
		"id": activity_id,
		"activity_text": TextDB.get_text(activity_key),
		"morning_title": morning_title,
		"morning_text": morning_text
	}

func generate_tomorrow_business_event_for_activity(activity_id: String) -> Dictionary:
	match activity_id:
		"chatting_neighbor":
			return make_tomorrow_business_event(
				"street_gets_busy",
				TextDB.get_text("UI_EVENT_STREET_BUSY"),
				TextDB.get_text("UI_EVENT_STREET_BUSY_TEXT"),
				"mixed",
				{"customer_spawn_interval_multiplier": 0.85}
			)

		"checking_notice":
			return make_tomorrow_business_event(
				"street_gets_busy",
				TextDB.get_text("UI_EVENT_STREET_BUSY"),
				TextDB.get_text("UI_EVENT_STREET_BUSY_NOTICE_TEXT"),
				"mixed",
				{"customer_spawn_interval_multiplier": 0.85}
			)

		"resting_cart":
			return make_tomorrow_business_event(
				"slow_easy_day",
				TextDB.get_text("UI_EVENT_SLOW_DAY"),
				TextDB.get_text("UI_EVENT_SLOW_DAY_TEXT"),
				"positive",
				{"customer_patience_multiplier": 1.25}
			)

		"sorting_ingredients":
			return make_tomorrow_business_event(
				"extra_raw_prep",
				TextDB.get_text("UI_EVENT_EXTRA_RAW_PREP"),
				TextDB.get_text("UI_EVENT_EXTRA_RAW_PREP_TEXT"),
				"positive",
				{"random_raw_stock_bonus": 2}
			)

		"reading_notes":
			var options: Array = [
				make_tomorrow_business_event(
					"market_friend",
					TextDB.get_text("UI_EVENT_MARKET_FRIEND"),
					TextDB.get_text("UI_EVENT_MARKET_FRIEND_TEXT"),
					"positive",
					{"emergency_shop_price_multiplier": 0.75}
				),
				make_tomorrow_business_event(
					"slow_easy_day",
					TextDB.get_text("UI_EVENT_SLOW_DAY"),
					TextDB.get_text("UI_EVENT_SLOW_DAY_TEXT"),
					"positive",
					{"customer_patience_multiplier": 1.25}
				)
			]

			return options[randi() % options.size()]

		_:
			return make_tomorrow_business_event(
				"slow_easy_day",
				TextDB.get_text("UI_EVENT_SLOW_DAY"),
				TextDB.get_text("UI_EVENT_SLOW_DAY_TEXT"),
				"positive",
				{"customer_patience_multiplier": 1.15}
			)

func make_tomorrow_business_event(
	event_id: String,
	title: String,
	text: String,
	tone: String,
	modifiers: Dictionary
) -> Dictionary:
	return {
		"id": event_id,
		"title": title,
		"text": text,
		"tone": tone,
		"modifiers": modifiers.duplicate(true)
	}

func activate_pending_tomorrow_event() -> Dictionary:
	if pending_tomorrow_event.is_empty():
		current_day_business_event = {}
		current_day_modifiers = {}
		return {}

	current_day_business_event = pending_tomorrow_event.duplicate(true)

	var modifiers = current_day_business_event.get("modifiers", {})

	if typeof(modifiers) == TYPE_DICTIONARY:
		current_day_modifiers = modifiers.duplicate(true)
	else:
		current_day_modifiers = {}

	pending_tomorrow_event = {}

	return current_day_business_event.duplicate(true)

func get_current_day_multiplier(modifier_id: String, default_value: float = 1.0) -> float:
	var value: float = default_value

	if not current_day_modifiers.is_empty() and current_day_modifiers.has(modifier_id):
		value *= float(current_day_modifiers.get(modifier_id, 1.0))

	var effect_manager: Node = get_node_or_null("/root/EffectManager")
	if effect_manager != null and effect_manager.has_method("get_multiplier"):
		value = effect_manager.get_multiplier(modifier_id, value)

	return value


func get_current_day_additive(modifier_id: String, default_value: float = 0.0) -> float:
	var value: float = default_value

	if not current_day_modifiers.is_empty() and current_day_modifiers.has(modifier_id):
		value += float(current_day_modifiers.get(modifier_id, 0.0))

	var effect_manager: Node = get_node_or_null("/root/EffectManager")
	if effect_manager != null and effect_manager.has_method("get_additive"):
		value = effect_manager.get_additive(modifier_id, value)

	return value

func get_current_night_activity_text() -> String:
	if current_night_activity.is_empty():
		return ""

	return str(current_night_activity.get("activity_text", ""))

func has_pending_morning_info() -> bool:
	if pending_morning_info.is_empty():
		return false

	return str(pending_morning_info.get("text", "")) != ""

func consume_pending_morning_info_lines() -> Array[String]:
	var lines: Array[String] = []

	if not has_pending_morning_info():
		return lines

	var title: String = str(pending_morning_info.get("title", TextDB.get_text("UI_MORNING_INFO_DEFAULT_TITLE")))
	var text: String = str(pending_morning_info.get("text", ""))
	var event = pending_morning_info.get("event", {})

	lines.append(title)

	if text != "":
		lines.append(text)

	if typeof(event) == TYPE_DICTIONARY and not event.is_empty():
		var event_title: String = str(event.get("title", TextDB.get_text("UI_TOMORROW_EVENT_DEFAULT_TITLE")))
		var event_text: String = str(event.get("text", ""))

		if event_text != "":
			lines.append("")
			lines.append(TextDB.get_text("UI_MORNING_EVENT_LINE") % [event_title, event_text])

	pending_morning_info = {}

	return lines

func get_basic_ingredient_ids() -> Array[String]:
	var result: Array[String] = []

	for item_id in basic_ingredient_ids:
		result.append(item_id)

	return result


func get_staple_item_ids() -> Array[String]:
	var result: Array[String] = []

	for item_id in staple_item_ids:
		result.append(item_id)

	return result


func get_supplier_order_item_ids() -> Array[String]:
	var result: Array[String] = []

	for item_id in basic_ingredient_ids:
		result.append(item_id)

	for item_id in staple_item_ids:
		result.append(item_id)

	return result


func get_supplier_package_options() -> Array:
	var result: Array = []

	for package_data in supplier_package_options:
		if typeof(package_data) == TYPE_DICTIONARY:
			result.append(package_data.duplicate(true))

	return result


func is_staple_item(item_id: String) -> bool:
	return staple_item_ids.has(item_id)


func get_supplier_delivery_seconds() -> float:
	return max(supplier_delivery_seconds, 0.1)


func get_supplier_base_price(item_id: String) -> float:
	if not supplier_base_prices.has(item_id):
		return 1.0

	return max(float(supplier_base_prices.get(item_id, 1.0)), 0.1)


func get_supplier_order_price(item_id: String, amount: int = 1) -> int:
	if amount <= 0:
		return 0

	var base_price: float = get_supplier_base_price(item_id)

	var multiplier: float = get_current_day_multiplier(
		"supplier_order_price_multiplier",
		1.0
	)

	var total: int = int(ceil(float(amount) * base_price * multiplier))

	return max(total, 1)


func get_supplier_order_price_for_items(items: Dictionary) -> int:
	var total: int = 0

	for item_id in items.keys():
		var amount: int = int(items.get(item_id, 0))

		if amount <= 0:
			continue

		total += get_supplier_order_price(str(item_id), amount)

	return total


func get_neighbor_emergency_price(item_id: String, amount: int = 1) -> int:
	if amount <= 0:
		return 0

	var base_price: float = get_supplier_base_price(item_id)
	var emergency_multiplier: float = neighbor_emergency_price_multiplier

	var day_multiplier: float = get_current_day_multiplier(
		"emergency_shop_price_multiplier",
		1.0
	)

	var raw_total: float = float(amount) * base_price * emergency_multiplier * day_multiplier
	var total: int = int(ceil(raw_total))

	return max(total, 1)


func get_neighbor_emergency_price_for_shortage(shortage: Dictionary) -> int:
	var total: int = 0

	for item_id in shortage.keys():
		var amount: int = int(shortage.get(item_id, 0))

		if amount <= 0:
			continue

		total += get_neighbor_emergency_price(str(item_id), amount)

	return total



func ensure_starting_money_for_new_run() -> void:
	_sync_runtime_state_from_fields()

	if current_day_in_run != 1:
		return

	if run_money > 0:
		return

	if run_total_income != 0:
		return

	run_money = starting_money
	_sync_runtime_state_from_fields()

	print("Starting money granted: ", starting_money)
