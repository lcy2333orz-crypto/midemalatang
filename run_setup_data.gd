extends Node

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

var current_raw_stock: Dictionary = {}
var current_cooked_stock: Dictionary = {}

var basic_ingredient_ids: Array[String] = [
	"spinach",
	"potato_slice",
	"tofu_puff"
]

var supplier_base_prices: Dictionary = {
	"spinach": 1,
	"potato_slice": 1,
	"tofu_puff": 2
}

var neighbor_emergency_price_multiplier: float = 3.0

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


func reset_run_setup() -> void:
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

	run_money = 0
	run_total_income = 0

	current_raw_stock = {}
	current_cooked_stock = {}

	current_day_special_spawn_plan = []
	today_special_customer_results = []
	generated_night_queue = []

	pending_gifts = []
	opened_gifts = []
	gift_sequence_id = 0

	active_effects = []

	shop_reputation = 50
	today_reputation_delta = 0

	today_customers_served = 0
	today_customers_failed = 0
	today_special_echo_records = []

	settlement_view_mode = "day"
	last_day_summary = {}
	last_run_summary = {}

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
	station_layout["delivery"] = "slot_b"
	station_layout["storage"] = "slot_c"
	station_layout["cooker_1"] = "slot_d"

	if ProgressData.has_second_cooker:
		station_layout["cooker_2"] = "slot_e"
		station_layout["emergency_shop"] = "slot_f"
	else:
		station_layout["cooker_2"] = ""
		station_layout["emergency_shop"] = "slot_e"


func setup_daily_special_customer_plan() -> void:
	current_day_special_spawn_plan = [
		{
			"type": "mouse",
			"name": "老鼠"
		}
	]


func add_pending_gift(source_type: String, source_name: String, result: String) -> Dictionary:
	gift_sequence_id += 1

	var display_name := ""
	var display_kind := ""

	if result == "good":
		display_name = "%s留下的祝愿" % source_name
		display_kind = "blessing"
	elif result == "bad":
		display_name = "%s留下的呸" % source_name
		display_kind = "spit"
	else:
		display_name = "%s留下的回响" % source_name
		display_kind = "echo"

	var gift_data := {
		"gift_id": "gift_%d" % gift_sequence_id,
		"source_type": source_type,
		"source_name": source_name,
		"result": result,
		"gift_type": "special_customer",
		"display_name": display_name,
		"display_kind": display_kind,
		"received_day": current_day_in_run,
		"received_order": gift_sequence_id,
		"opened": false,
		"current_options": []
	}

	pending_gifts.append(gift_data)
	record_today_special_echo(display_name, result)

	print("Special customer echo added: ", gift_data)

	return gift_data

func get_pending_gift_index_by_id(gift_id: String) -> int:
	for i in range(pending_gifts.size()):
		var gift_data = pending_gifts[i]

		if typeof(gift_data) != TYPE_DICTIONARY:
			continue

		if str(gift_data.get("gift_id", "")) == gift_id:
			return i

	return -1


func get_unopened_gift_by_id(gift_id: String) -> Dictionary:
	var index := get_pending_gift_index_by_id(gift_id)

	if index == -1:
		return {}

	var gift_data: Dictionary = pending_gifts[index]

	if bool(gift_data.get("opened", false)):
		return {}

	return gift_data.duplicate(true)


func is_gift_opened(gift_id: String) -> bool:
	var index := get_pending_gift_index_by_id(gift_id)

	if index == -1:
		return false

	var gift_data: Dictionary = pending_gifts[index]

	return bool(gift_data.get("opened", false))


func get_gift_current_options(gift_id: String) -> Array:
	var index := get_pending_gift_index_by_id(gift_id)

	if index == -1:
		return []

	var gift_data: Dictionary = pending_gifts[index]
	var options = gift_data.get("current_options", [])

	if typeof(options) != TYPE_ARRAY:
		return []

	return options.duplicate(true)


func set_gift_current_options(gift_id: String, options: Array) -> void:
	var index := get_pending_gift_index_by_id(gift_id)

	if index == -1:
		return

	var saved_options: Array = []

	for option in options:
		if typeof(option) == TYPE_DICTIONARY:
			saved_options.append(option.duplicate(true))

	pending_gifts[index]["current_options"] = saved_options


func mark_gift_opened(gift_id: String, chosen_card: Dictionary) -> Dictionary:
	var index := get_pending_gift_index_by_id(gift_id)

	if index == -1:
		return {}

	var gift_data: Dictionary = pending_gifts[index]

	if bool(gift_data.get("opened", false)):
		return gift_data.duplicate(true)

	gift_data["opened"] = true
	gift_data["opened_day"] = current_day_in_run
	gift_data["chosen_card_id"] = str(chosen_card.get("id", "unknown_card"))
	gift_data["chosen_card_name"] = str(chosen_card.get("name", "未知卡牌"))

	pending_gifts[index] = gift_data
	opened_gifts.append(gift_data.duplicate(true))

	print("Special customer echo opened: ", gift_data)

	return gift_data.duplicate(true)

func get_unopened_pending_gifts() -> Array:
	var result: Array = []

	for gift_data in pending_gifts:
		if typeof(gift_data) != TYPE_DICTIONARY:
			continue

		if not bool(gift_data.get("opened", false)):
			result.append(gift_data)

	return result


func has_unopened_pending_gifts() -> bool:
	return not get_unopened_pending_gifts().is_empty()


func get_pending_gift_lines() -> Array[String]:
	var lines: Array[String] = []
	var unopened_gifts := get_unopened_pending_gifts()

	if unopened_gifts.is_empty():
		lines.append("当前没有未查看的特殊客人回响。")
		return lines

	lines.append("特殊客人的回响：")

	for gift_data in unopened_gifts:
		var display_name := str(gift_data.get("display_name", ""))

		if display_name == "":
			var source_name := str(gift_data.get("source_name", "特殊客人"))
			var result := str(gift_data.get("result", "neutral"))

			if result == "good":
				display_name = "%s留下的祝愿" % source_name
			elif result == "bad":
				display_name = "%s留下的呸" % source_name
			else:
				display_name = "%s留下的回响" % source_name

		lines.append(" - %s" % display_name)

	return lines

func reset_today_stall_echo_stats() -> void:
	today_customers_served = 0
	today_customers_failed = 0
	today_special_echo_records = []


func record_today_served_customer() -> void:
	today_customers_served += 1


func record_today_failed_customer() -> void:
	today_customers_failed += 1


func record_today_special_echo(display_name: String, result: String) -> void:
	today_special_echo_records.append({
		"display_name": display_name,
		"result": result
	})


func get_today_stall_echo_lines() -> Array[String]:
	var lines: Array[String] = []

	lines.append("今日小摊回响：")
	lines.append("服务顾客：%d" % today_customers_served)
	lines.append("满意离开：%d" % today_customers_served)
	lines.append("遗憾离开：%d" % today_customers_failed)

	if today_special_echo_records.is_empty():
		lines.append("特殊客人回响：无")
	else:
		var echo_names: Array[String] = []

		for record in today_special_echo_records:
			if typeof(record) != TYPE_DICTIONARY:
				continue

			echo_names.append(str(record.get("display_name", "特殊客人的回响")))

		if echo_names.is_empty():
			lines.append("特殊客人回响：无")
		else:
			lines.append("特殊客人回响：%s" % "，".join(echo_names))

	return lines

func generate_night_background_activity(has_next_day: bool = true) -> Dictionary:
	var options: Array = []

	if has_next_day:
		options = [
			{
				"id": "reading_notes",
				"activity_text": "小猫正在翻看一本油乎乎的小本子。",
				"morning_title": "昨晚小猫翻了翻小本子",
				"morning_text": "小猫从笔记里整理出了一点明日小摊情报。"
			},
			{
				"id": "chatting_neighbor",
				"activity_text": "小猫在和路过的街坊小声聊天。",
				"morning_title": "昨晚小猫和街坊聊了聊",
				"morning_text": "小猫听到了一些关于明天街口的小消息。"
			},
			{
				"id": "checking_notice",
				"activity_text": "小猫认真看了看贴在街口的小纸条。",
				"morning_title": "昨晚小猫看了街口的小纸条",
				"morning_text": "小猫注意到明天附近可能会有些变化。"
			},
			{
				"id": "sorting_ingredients",
				"activity_text": "小猫把剩下的食材重新数了一遍。",
				"morning_title": "昨晚小猫整理了食材",
				"morning_text": "小猫对明天的备货有了一点想法。"
			},
			{
				"id": "resting_cart",
				"activity_text": "小猫趴在餐车旁边，尾巴轻轻晃着。",
				"morning_title": "昨晚小猫好好休息了一会儿",
				"morning_text": "小猫决定明天也要稳稳地把热乎乎的东西端出去。"
			}
		]
	else:
		options = [
			{
				"id": "final_rest",
				"activity_text": "小猫收好餐车，安静地看着今天的小摊灯光慢慢暗下去。",
				"morning_title": "",
				"morning_text": ""
			}
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

func generate_tomorrow_business_event_for_activity(activity_id: String) -> Dictionary:
	match activity_id:
		"chatting_neighbor":
			return make_tomorrow_business_event(
				"street_gets_busy",
				"街口热闹",
				"今天路过小摊的人会多一点。",
				"mixed",
				{
					"customer_spawn_interval_multiplier": 0.85
				}
			)

		"checking_notice":
			return make_tomorrow_business_event(
				"street_gets_busy",
				"街口热闹",
				"今天附近人流会比平时多一点。",
				"mixed",
				{
					"customer_spawn_interval_multiplier": 0.85
				}
			)

		"resting_cart":
			return make_tomorrow_business_event(
				"slow_easy_day",
				"慢悠悠的一天",
				"今天大家好像都不太着急。",
				"positive",
				{
					"customer_patience_multiplier": 1.25
				}
			)

		"sorting_ingredients":
			return make_tomorrow_business_event(
				"extra_raw_prep",
				"早上多备一点",
				"小猫今天早上多找出了一点能用的生食材。",
				"positive",
				{
					"random_raw_stock_bonus": 2
				}
			)

		"reading_notes":
			var options := [
				make_tomorrow_business_event(
					"market_friend",
					"菜摊熟脸",
					"今天临时补货会便宜一点。",
					"positive",
					{
						"emergency_shop_price_multiplier": 0.75
					}
				),
				make_tomorrow_business_event(
					"slow_easy_day",
					"慢悠悠的一天",
					"今天大家好像都不太着急。",
					"positive",
					{
						"customer_patience_multiplier": 1.25
					}
				)
			]

			return options[randi() % options.size()]

		_:
			return make_tomorrow_business_event(
				"slow_easy_day",
				"慢悠悠的一天",
				"今天大家好像都不太着急。",
				"positive",
				{
					"customer_patience_multiplier": 1.15
				}
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
	if current_day_modifiers.is_empty():
		return default_value

	if not current_day_modifiers.has(modifier_id):
		return default_value

	return float(current_day_modifiers.get(modifier_id, default_value))

func get_current_day_additive(modifier_id: String, default_value: float = 0.0) -> float:
	if current_day_modifiers.is_empty():
		return default_value

	if not current_day_modifiers.has(modifier_id):
		return default_value

	return float(current_day_modifiers.get(modifier_id, default_value))

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

	var title := str(pending_morning_info.get("title", "昨晚小猫获得的信息"))
	var text := str(pending_morning_info.get("text", ""))
	var event = pending_morning_info.get("event", {})

	lines.append(title)

	if text != "":
		lines.append(text)

	if typeof(event) == TYPE_DICTIONARY and not event.is_empty():
		var event_title := str(event.get("title", "明日营业变化"))
		var event_text := str(event.get("text", ""))

		if event_text != "":
			lines.append("")
			lines.append("%s：%s" % [event_title, event_text])

	pending_morning_info = {}

	return lines

func get_basic_ingredient_ids() -> Array[String]:
	var result: Array[String] = []

	for item_id in basic_ingredient_ids:
		result.append(item_id)

	return result

func get_supplier_base_price(item_id: String) -> int:
	if not supplier_base_prices.has(item_id):
		return 1

	return max(int(supplier_base_prices.get(item_id, 1)), 1)

func get_supplier_order_price(item_id: String, amount: int = 1) -> int:
	if amount <= 0:
		return 0

	var base_price := get_supplier_base_price(item_id)
	var multiplier := get_current_day_multiplier(
		"supplier_order_price_multiplier",
		1.0
	)

	var total := int(ceil(float(base_price * amount) * multiplier))

	return max(total, 1)

func get_supplier_order_price_for_items(items: Dictionary) -> int:
	var total := 0

	for item_id in items.keys():
		var amount := int(items.get(item_id, 0))

		if amount <= 0:
			continue

		total += get_supplier_order_price(str(item_id), amount)

	return total

func get_neighbor_emergency_price(item_id: String, amount: int = 1) -> int:
	if amount <= 0:
		return 0

	var base_price := get_supplier_base_price(item_id)
	var emergency_multiplier := neighbor_emergency_price_multiplier

	var day_multiplier := get_current_day_multiplier(
		"emergency_shop_price_multiplier",
		1.0
	)

	var raw_total := float(base_price * amount) * emergency_multiplier * day_multiplier
	var total := int(ceil(raw_total))

	return max(total, 1)

func get_neighbor_emergency_price_for_shortage(shortage: Dictionary) -> int:
	var total := 0

	for item_id in shortage.keys():
		var amount := int(shortage.get(item_id, 0))

		if amount <= 0:
			continue

		total += get_neighbor_emergency_price(str(item_id), amount)

	return total
