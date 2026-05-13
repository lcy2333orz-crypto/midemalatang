extends Area2D

@export var station_name: String = ""
@export var interaction_label: String = ""
@export var interaction_priority: int = 0

const DEBUG_STATION_LABELS: Dictionary = {
	"DisposablePlateStack": "UI_STATION_DISPOSABLE_PLATE",
	"Counter": "柜台",
	"Cooker": "大锅",
	"DeliveryPoint": "出餐口",
	"StorageArea": "仓库",
	"TrashBin": "UI_STATION_TRASH_BIN",
	"EmergencyShop": "应急采购",
	"GlassNoodleBasket": "粉丝篮",
	"NoodleBasket": "面篮",
	"StapleLadle1": "漏勺1",
	"StapleLadle2": "漏勺2",
	"GiftBox": "礼物"
}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_create_or_update_debug_station_label()


func _process(_delta: float) -> void:
	_create_or_update_debug_station_label()
	_update_debug_station_label_position()


func _create_or_update_debug_station_label() -> void:
	var label_text: String = str(DEBUG_STATION_LABELS.get(station_name, ""))
	if label_text == "":
		return

	if label_text.begins_with("UI_"):
		label_text = TextDB.get_text(label_text)

	var label_parent: Node = _get_debug_station_label_parent()
	if label_parent == null:
		return

	var label_name: String = _get_debug_station_label_name()
	var label: Label = label_parent.get_node_or_null(label_name) as Label
	if label == null:
		label = Label.new()
		label.name = label_name
		label_parent.add_child(label)

	var label_size: Vector2 = Vector2(132, 26)

	if station_name == "Cooker":
		label_size.x = 220
	elif station_name == "EmergencyShop":
		label_size.x = 150

	label.text = label_text
	label.size = label_size
	label.scale = Vector2.ONE
	label.z_as_relative = false
	label.z_index = 350
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.BLACK)
	label.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 14)
	_update_debug_station_label_position()


func _update_debug_station_label_position() -> void:
	var station_node: Node = get_parent()
	if station_node == null:
		return

	var label_parent: Node = _get_debug_station_label_parent()
	if label_parent == null:
		return

	var label: Label = label_parent.get_node_or_null(_get_debug_station_label_name()) as Label
	if label == null:
		return

	var station_position: Vector2 = Vector2.ZERO
	if station_node is Node2D:
		station_position = get_viewport().get_canvas_transform() * (station_node as Node2D).global_position

	var label_offset: Vector2 = Vector2(-label.size.x * 0.5, -label.size.y * 0.5)
	label.position = station_position + label_offset


func _get_debug_station_label_parent() -> Node:
	var game_ui: Node = get_tree().get_first_node_in_group("game_ui")
	if game_ui != null:
		return game_ui

	return get_parent()


func _get_debug_station_label_name() -> String:
	return "DebugStationNameLabel_%s" % station_name


func get_interaction_priority() -> int:
	if interaction_priority != 0:
		return interaction_priority

	match station_name:
		"Counter":
			return 100
		"DeliveryPoint":
			return 95
		"StapleLadle1", "StapleLadle2":
			return 90
		"DisposablePlateStack":
			return 86
		"GlassNoodleBasket", "NoodleBasket":
			return 85
		"Cooker":
			return 80
		"EmergencyShop":
			return 70
		"StorageArea":
			return 65
		"TrashBin":
			return 66
		"GiftBox":
			return 50
		_:
			return 10


func get_interaction_prompt() -> String:
	if interaction_label.strip_edges() != "":
		return interaction_label

	var game_manager = get_tree().get_first_node_in_group("game_manager")

	if game_manager != null and game_manager.station_interaction_system != null:
		return game_manager.station_interaction_system.get_interaction_prompt(station_name)

	match station_name:
		_:
			return TextDB.get_text("UI_PROMPT_INTERACT")

func interact() -> void:
	print("Interact with ", station_name)

	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager == null:
		print("No game manager found.")
		return

	game_manager.station_interaction_system.interact(station_name)


func toggle_business() -> void:
	if station_name != "Counter":
		print("This station cannot toggle business.")
		return

	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager == null:
		print("No game manager found.")
		return

	if game_manager.is_round_closing or game_manager.has_round_finished:
		print("Round is closing or already finished. Business cannot be reopened.")
		return

	game_manager.station_interaction_system.toggle_business(station_name)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	if body.has_method("register_nearby_station"):
		body.register_nearby_station(self)

	if station_name == "StorageArea":
		var game_manager = get_tree().get_first_node_in_group("game_manager")

		if game_manager != null and game_manager.station_interaction_system != null:
			game_manager.station_interaction_system.on_player_entered_station(station_name)


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	if body.has_method("unregister_nearby_station"):
		body.unregister_nearby_station(self)

	if station_name == "StorageArea":
		var game_ui = get_tree().get_first_node_in_group("game_ui")

		if game_ui != null:
			game_ui.hide_stock()
