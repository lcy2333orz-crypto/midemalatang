extends Node

var card_db: Dictionary = {}
var card_index: Dictionary = {}


func _ready() -> void:
	load_card_db()


func load_card_db() -> void:
	var file := FileAccess.open("res://data/card_db.json", FileAccess.READ)

	if file == null:
		push_error("card_db.json not found")
		card_db = {}
		card_index = {}
		return

	var content := file.get_as_text()
	var json := JSON.new()
	var result := json.parse(content)

	if result != OK:
		push_error("card_db.json parse failed: " + json.get_error_message())
		card_db = {}
		card_index = {}
		return

	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("card_db.json root must be a Dictionary")
		card_db = {}
		card_index = {}
		return

	card_db = json.data
	_rebuild_card_index()


func _rebuild_card_index() -> void:
	card_index = {}

	var pools: Dictionary = card_db.get("pools", {})

	for pool_name in pools.keys():
		var pool = pools[pool_name]

		if typeof(pool) != TYPE_ARRAY:
			continue

		for card_data in pool:
			if typeof(card_data) != TYPE_DICTIONARY:
				continue

			var card_id := str(card_data.get("id", ""))

			if card_id == "":
				continue

			card_index[card_id] = card_data


func get_card_definition(card_id: String) -> Dictionary:
	if card_index.has(card_id):
		return card_index[card_id].duplicate(true)

	return {}


func get_card_name(card_id: String) -> String:
	var card_data := get_card_definition(card_id)

	if card_data.has("name"):
		return str(card_data["name"])

	return card_id


func get_card_description(card_id: String) -> String:
	var card_data := get_card_definition(card_id)

	if card_data.has("description"):
		return str(card_data["description"])

	return ""


func get_active_effect_lines() -> Array[String]:
	var lines: Array[String] = []

	if RunSetupData.active_effects.is_empty():
		lines.append("当前没有已获得效果。")
		return lines

	lines.append("已获得效果：")

	for effect_data in RunSetupData.active_effects:
		if typeof(effect_data) != TYPE_DICTIONARY:
			continue

		var source := str(effect_data.get("source", "未知来源"))
		var effect_id := str(effect_data.get("effect_id", ""))
		var effect_name := str(effect_data.get("effect", ""))

		if effect_name == "":
			effect_name = get_card_name(effect_id)

		var description := get_card_description(effect_id)

		if description == "":
			lines.append(" - [%s] %s" % [source, effect_name])
		else:
			lines.append(" - [%s] %s：%s" % [source, effect_name, description])

	return lines


func get_multiplier(modifier_id: String, default_value: float = 1.0) -> float:
	var value := default_value

	for effect_data in RunSetupData.active_effects:
		if typeof(effect_data) != TYPE_DICTIONARY:
			continue

		var effect_id := str(effect_data.get("effect_id", ""))
		var card_data := get_card_definition(effect_id)
		var modifiers = card_data.get("modifiers", {})

		if typeof(modifiers) != TYPE_DICTIONARY:
			continue

		if modifiers.has(modifier_id):
			value *= float(modifiers[modifier_id])

	return value


func get_additive(modifier_id: String, default_value: float = 0.0) -> float:
	var value := default_value

	for effect_data in RunSetupData.active_effects:
		if typeof(effect_data) != TYPE_DICTIONARY:
			continue

		var effect_id := str(effect_data.get("effect_id", ""))
		var card_data := get_card_definition(effect_id)
		var modifiers = card_data.get("modifiers", {})

		if typeof(modifiers) != TYPE_DICTIONARY:
			continue

		if modifiers.has(modifier_id):
			value += float(modifiers[modifier_id])

	return value

func get_cards_for_pool(pool_name: String) -> Array:
	var pools: Dictionary = card_db.get("pools", {})

	if not pools.has(pool_name):
		return []

	var pool = pools[pool_name]

	if typeof(pool) != TYPE_ARRAY:
		return []

	var result: Array = []

	for card_data in pool:
		if typeof(card_data) != TYPE_DICTIONARY:
			continue

		result.append(card_data.duplicate(true))

	return result


func get_card_options_for_special_echo(gift_data: Dictionary) -> Array:
	var result := str(gift_data.get("result", "neutral"))
	var pool_name := "fallback"

	if result == "good":
		pool_name = "good"
	elif result == "bad":
		pool_name = "bad"

	var options := get_cards_for_pool(pool_name)

	if options.size() < 3:
		options = get_cards_for_pool("fallback")

	if options.size() > 3:
		options = options.slice(0, 3)

	return options
