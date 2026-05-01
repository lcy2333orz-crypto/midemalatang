extends Node

var current_language: String = "zh"
var texts: Dictionary = {}

var item_key_map := {
	"none": "UI_ITEM_NONE",
	"glass_noodle": "UI_ITEM_GLASS_NOODLE",
	"noodle": "UI_ITEM_NOODLE",
	"spinach": "UI_ITEM_SPINACH",
	"potato_slice": "UI_ITEM_POTATO_SLICE",
	"tofu_puff": "UI_ITEM_TOFU_PUFF"
}

var status_key_map := {
	"waiting_restock": "UI_STATUS_WAITING_RESTOCK",
	"ready_delivery": "UI_STATUS_READY_DELIVERY",
	"cooking": "UI_STATUS_COOKING",
	"waiting_cook": "UI_STATUS_WAITING_COOK"
}

func _ready() -> void:
	load_json()

func load_json() -> void:
	var file := FileAccess.open("res://data/text_db.json", FileAccess.READ)

	if file == null:
		push_error("text_db.json not found")
		texts = {}
		return

	var content := file.get_as_text()
	var json := JSON.new()
	var result := json.parse(content)

	if result != OK:
		push_error("JSON parse failed: " + json.get_error_message())
		texts = {}
		return

	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("text_db.json root must be a Dictionary")
		texts = {}
		return

	texts = json.data

func set_language(language_code: String) -> void:
	if texts.has(language_code):
		current_language = language_code

func get_text(key: String) -> String:
	var lang_table: Dictionary = texts.get(current_language, {})

	if lang_table.has(key):
		return str(lang_table[key])

	var zh_table: Dictionary = texts.get("zh", {})

	if zh_table.has(key):
		return str(zh_table[key])

	return key

func get_item_name(item_id: String) -> String:
	if item_key_map.has(item_id):
		return get_text(item_key_map[item_id])

	return item_id

func get_status_name(status_id: String) -> String:
	if status_key_map.has(status_id):
		return get_text(status_key_map[status_id])

	return status_id
