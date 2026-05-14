class_name RestaurantStationArea
extends Area2D

@export var station_name: String = ""
@export var station_label: String = ""
@export var interaction_priority: int = 0

var debug_label: Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_create_label()


func _process(_delta: float) -> void:
	_update_label()


func get_interaction_priority() -> int:
	if interaction_priority != 0:
		return interaction_priority

	match station_name:
		"Counter":
			return 120
		"DiningTable1", "DiningTable2", "DiningTable3", "TakeoutPickup":
			return 110
		"WaitingOrderArea":
			return 100
		"CookerStation1", "CookerStation2":
			return 95
		"SauceStation", "PackingArea":
			return 90
		_:
			return 20


func get_interaction_prompt() -> String:
	return "[E] %s" % _get_label_text()


func interact() -> void:
	var manager: Node = get_tree().get_first_node_in_group("restaurant_game_manager")
	if manager != null and manager.has_method("interact_with_station"):
		manager.interact_with_station(station_name)


func _create_label() -> void:
	if debug_label != null:
		return
	debug_label = Label.new()
	debug_label.name = "RestaurantStationLabel"
	debug_label.position = Vector2(-72, -52)
	debug_label.size = Vector2(144, 22)
	debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	debug_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	debug_label.add_theme_font_size_override("font_size", 13)
	debug_label.add_theme_color_override("font_color", Color.BLACK)
	debug_label.add_theme_color_override("font_outline_color", Color.WHITE)
	debug_label.add_theme_constant_override("outline_size", 3)
	get_parent().call_deferred("add_child", debug_label)


func _update_label() -> void:
	if debug_label == null:
		return
	debug_label.text = _get_label_text()


func _get_label_text() -> String:
	if station_label.strip_edges() != "":
		return station_label
	return station_name


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("register_nearby_station"):
		body.register_nearby_station(self)


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("unregister_nearby_station"):
		body.unregister_nearby_station(self)
