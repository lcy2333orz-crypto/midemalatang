class_name RunDayEventState
extends RefCounted

var owner = null


func bind(run_setup_data: Node) -> void:
	owner = run_setup_data


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	if owner == null:
		warnings.append("RunDayEventState is not bound.")
		return warnings

	if typeof(owner.current_day_special_spawn_plan) != TYPE_ARRAY:
		warnings.append("RunDayEventState: current_day_special_spawn_plan is not an Array.")

	if typeof(owner.current_day_modifiers) != TYPE_DICTIONARY:
		warnings.append("RunDayEventState: current_day_modifiers is not a Dictionary.")

	if typeof(owner.pending_tomorrow_event) != TYPE_DICTIONARY:
		warnings.append("RunDayEventState: pending_tomorrow_event is not a Dictionary.")

	return warnings


func setup_daily_special_customer_plan() -> void:
	if owner != null and owner.has_method("is_tutorial_day") and owner.is_tutorial_day():
		owner.current_day_special_spawn_plan = []
		print("Tutorial day: special customer plan disabled.")
		return

	owner.current_day_special_spawn_plan = [
		{
			"type": "mouse",
			"name": TextDB.get_text("UI_SPECIAL_CUSTOMER_MOUSE")
		}
	]


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
	owner.current_night_activity = chosen.duplicate(true)

	if has_next_day:
		owner.pending_tomorrow_event = generate_tomorrow_business_event_for_activity(str(chosen.get("id", "")))
		owner.pending_morning_info = {
			"title": str(chosen.get("morning_title", "")),
			"text": str(chosen.get("morning_text", "")),
			"source_activity_id": str(chosen.get("id", "")),
			"event": owner.pending_tomorrow_event.duplicate(true)
		}
	else:
		owner.pending_tomorrow_event = {}
		owner.pending_morning_info = {}

	return owner.current_night_activity.duplicate(true)


func generate_tomorrow_business_event_for_activity(activity_id: String) -> Dictionary:
	match activity_id:
		"chatting_neighbor":
			return make_tomorrow_business_event("street_gets_busy", TextDB.get_text("UI_EVENT_STREET_BUSY"), TextDB.get_text("UI_EVENT_STREET_BUSY_TEXT"), "mixed", {"customer_spawn_interval_multiplier": 0.85})
		"checking_notice":
			return make_tomorrow_business_event("street_gets_busy", TextDB.get_text("UI_EVENT_STREET_BUSY"), TextDB.get_text("UI_EVENT_STREET_BUSY_NOTICE_TEXT"), "mixed", {"customer_spawn_interval_multiplier": 0.85})
		"resting_cart":
			return make_tomorrow_business_event("slow_easy_day", TextDB.get_text("UI_EVENT_SLOW_DAY"), TextDB.get_text("UI_EVENT_SLOW_DAY_TEXT"), "positive", {"customer_patience_multiplier": 1.25})
		"sorting_ingredients":
			return make_tomorrow_business_event("extra_raw_prep", TextDB.get_text("UI_EVENT_EXTRA_RAW_PREP"), TextDB.get_text("UI_EVENT_EXTRA_RAW_PREP_TEXT"), "positive", {"random_raw_stock_bonus": 2})
		"reading_notes":
			var options: Array = [
				make_tomorrow_business_event("market_friend", TextDB.get_text("UI_EVENT_MARKET_FRIEND"), TextDB.get_text("UI_EVENT_MARKET_FRIEND_TEXT"), "positive", {"emergency_shop_price_multiplier": 0.75}),
				make_tomorrow_business_event("slow_easy_day", TextDB.get_text("UI_EVENT_SLOW_DAY"), TextDB.get_text("UI_EVENT_SLOW_DAY_TEXT"), "positive", {"customer_patience_multiplier": 1.25})
			]
			return options[randi() % options.size()]
		_:
			return make_tomorrow_business_event("slow_easy_day", TextDB.get_text("UI_EVENT_SLOW_DAY"), TextDB.get_text("UI_EVENT_SLOW_DAY_TEXT"), "positive", {"customer_patience_multiplier": 1.15})


func make_tomorrow_business_event(event_id: String, title: String, text: String, tone: String, modifiers: Dictionary) -> Dictionary:
	return {
		"id": event_id,
		"title": title,
		"text": text,
		"tone": tone,
		"modifiers": modifiers.duplicate(true)
	}


func activate_pending_tomorrow_event() -> Dictionary:
	if owner.pending_tomorrow_event.is_empty():
		owner.current_day_business_event = {}
		owner.current_day_modifiers = {}
		return {}

	owner.current_day_business_event = owner.pending_tomorrow_event.duplicate(true)

	var modifiers = owner.current_day_business_event.get("modifiers", {})

	if typeof(modifiers) == TYPE_DICTIONARY:
		owner.current_day_modifiers = modifiers.duplicate(true)
	else:
		owner.current_day_modifiers = {}

	owner.pending_tomorrow_event = {}

	return owner.current_day_business_event.duplicate(true)


func get_current_day_multiplier(modifier_id: String, default_value: float = 1.0) -> float:
	var value: float = default_value

	if not owner.current_day_modifiers.is_empty() and owner.current_day_modifiers.has(modifier_id):
		value *= float(owner.current_day_modifiers.get(modifier_id, 1.0))

	var effect_manager: Node = owner.get_node_or_null("/root/EffectManager")
	if effect_manager != null and effect_manager.has_method("get_multiplier"):
		value = effect_manager.get_multiplier(modifier_id, value)

	return value


func get_current_day_additive(modifier_id: String, default_value: float = 0.0) -> float:
	var value: float = default_value

	if not owner.current_day_modifiers.is_empty() and owner.current_day_modifiers.has(modifier_id):
		value += float(owner.current_day_modifiers.get(modifier_id, 0.0))

	var effect_manager: Node = owner.get_node_or_null("/root/EffectManager")
	if effect_manager != null and effect_manager.has_method("get_additive"):
		value = effect_manager.get_additive(modifier_id, value)

	return value


func get_current_night_activity_text() -> String:
	if owner.current_night_activity.is_empty():
		return ""

	return str(owner.current_night_activity.get("activity_text", ""))


func has_pending_morning_info() -> bool:
	if owner.pending_morning_info.is_empty():
		return false

	return str(owner.pending_morning_info.get("text", "")) != ""


func consume_pending_morning_info_lines() -> Array[String]:
	var lines: Array[String] = []

	if not has_pending_morning_info():
		return lines

	var title: String = str(owner.pending_morning_info.get("title", TextDB.get_text("UI_MORNING_INFO_DEFAULT_TITLE")))
	var text: String = str(owner.pending_morning_info.get("text", ""))
	var event = owner.pending_morning_info.get("event", {})

	lines.append(title)

	if text != "":
		lines.append(text)

	if typeof(event) == TYPE_DICTIONARY and not event.is_empty():
		var event_title: String = str(event.get("title", TextDB.get_text("UI_TOMORROW_EVENT_DEFAULT_TITLE")))
		var event_text: String = str(event.get("text", ""))

		if event_text != "":
			lines.append("")
			lines.append(TextDB.get_text("UI_MORNING_EVENT_LINE") % [event_title, event_text])

	owner.pending_morning_info = {}

	return lines


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
