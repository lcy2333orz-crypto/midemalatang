class_name CookingPot
extends Node2D

@export var pot_id: String = ""

var content_bowl: OrderBowl = null
var is_on_heat: bool = false
var current_station: CookerStation = null
var visual: Polygon2D = null
var label: Label = null


func _ready() -> void:
	_ensure_visuals()
	refresh_visual()


func _process(delta: float) -> void:
	if is_on_heat and content_bowl != null and is_instance_valid(content_bowl):
		var manager: RestaurantGameManager = _get_restaurant_manager()
		var tutorial_protected: bool = manager != null and manager._is_tutorial_cooked_pot_protected()
		if tutorial_protected and content_bowl.status == OrderBowl.STATUS_COOKED and not content_bowl.is_overcooked():
			refresh_visual()
			return
		var was_cooked: bool = content_bowl.status == OrderBowl.STATUS_COOKED and not content_bowl.is_overcooked()
		var cook_delta: float = delta
		if tutorial_protected and content_bowl.status == OrderBowl.STATUS_COOKING:
			cook_delta = min(delta, max(content_bowl.ingredient_time_required - content_bowl.cook_time, 0.0))
		content_bowl.update_cooking(cook_delta)
		var became_cooked: bool = not was_cooked and content_bowl.status == OrderBowl.STATUS_COOKED and not content_bowl.is_overcooked()
		refresh_visual()
		if became_cooked and manager != null:
			manager.notify_tutorial_bowl_became_cooked(content_bowl)


func is_empty() -> bool:
	_clean_invalid_content()
	return content_bowl == null


func has_content() -> bool:
	return not is_empty()


func has_raw_content() -> bool:
	_clean_invalid_content()
	return content_bowl != null and content_bowl.status == OrderBowl.STATUS_COOKING and not content_bowl.is_overcooked()


func has_ready_content() -> bool:
	_clean_invalid_content()
	return content_bowl != null and content_bowl.status == OrderBowl.STATUS_COOKED and not content_bowl.is_overcooked()


func has_overcooked_content() -> bool:
	_clean_invalid_content()
	return content_bowl != null and content_bowl.is_overcooked()


func can_accept_order_bowl(bowl: OrderBowl) -> bool:
	return is_empty() and bowl != null and is_instance_valid(bowl) and not bowl.is_empty_holder and bowl.status == OrderBowl.STATUS_WAITING and bowl.is_staple_ready_for_cooking()


func add_order_bowl(bowl: OrderBowl) -> bool:
	if not can_accept_order_bowl(bowl):
		return false
	content_bowl = bowl
	content_bowl.status = OrderBowl.STATUS_COOKING
	content_bowl.cook_time = 0.0
	content_bowl.is_empty_holder = false
	content_bowl.refresh_visuals()
	if content_bowl.get_parent() != null:
		content_bowl.get_parent().remove_child(content_bowl)
	add_child(content_bowl)
	content_bowl.visible = false
	content_bowl.position = Vector2.ZERO
	refresh_visual()
	return true


func can_scoop_to_empty_bowl(empty_bowl: OrderBowl) -> bool:
	_clean_invalid_content()
	return content_bowl != null and empty_bowl != null and is_instance_valid(empty_bowl) and empty_bowl.is_empty_holder and content_bowl.status == OrderBowl.STATUS_COOKED and not content_bowl.is_overcooked() and empty_bowl.order_id == content_bowl.order_id


func scoop_to_empty_bowl(empty_bowl: OrderBowl) -> bool:
	if not can_scoop_to_empty_bowl(empty_bowl):
		return false
	_copy_content_to_bowl(empty_bowl, content_bowl)
	content_bowl.queue_free()
	content_bowl = null
	refresh_visual()
	return true


func clear_content() -> OrderBowl:
	_clean_invalid_content()
	if content_bowl == null:
		return null
	var result: OrderBowl = content_bowl
	content_bowl = null
	refresh_visual()
	return result


func trash_content() -> void:
	var bowl: OrderBowl = clear_content()
	if bowl != null and is_instance_valid(bowl):
		bowl.queue_free()


func set_on_heat(value: bool) -> void:
	is_on_heat = value


func attach_to_holder(holder: Node2D) -> void:
	if get_parent() != null:
		get_parent().remove_child(self)
	holder.add_child(self)
	position = Vector2(0, -36)
	z_index = 24
	set_on_heat(false)
	refresh_visual()


func detach_to_world(world_parent: Node, world_position: Vector2) -> void:
	if get_parent() != null:
		get_parent().remove_child(self)
	world_parent.add_child(self)
	global_position = world_position
	z_index = 16
	set_on_heat(false)
	refresh_visual()


func refresh_visual() -> void:
	_ensure_visuals()
	_clean_invalid_content()
	if content_bowl == null:
		visual.color = Color(0.22, 0.22, 0.24, 1.0)
		label.text = "空锅"
	elif content_bowl.is_overcooked():
		visual.color = Color(0.05, 0.04, 0.035, 1.0)
		label.text = "煮糊"
	elif content_bowl.status == OrderBowl.STATUS_COOKED:
		visual.color = Color(0.28, 0.82, 0.38, 1.0)
		label.text = "已熟"
	else:
		visual.color = Color(0.95, 0.48, 0.18, 1.0)
		label.text = "加热中"


func get_content_status_text() -> String:
	_clean_invalid_content()
	if content_bowl == null:
		return "空锅"
	if content_bowl.is_overcooked():
		return "煮糊"
	if content_bowl.status == OrderBowl.STATUS_COOKED:
		return "已熟"
	return "加热中"


func _copy_content_to_bowl(target: OrderBowl, source: OrderBowl) -> void:
	target.order_id = source.order_id
	target.ingredients = source.ingredients.duplicate(true)
	target.staple_type = source.staple_type
	target.spice_level = source.spice_level
	target.service_mode = source.service_mode
	target.table_id = source.table_id
	target.status = OrderBowl.STATUS_COOKED
	target.staple_state = source.staple_state
	target.sauces = source.sauces.duplicate()
	target.required_chili_count = source.required_chili_count
	target.added_chili_count = source.added_chili_count
	target.is_empty_holder = false
	target.staple_added = source.staple_added
	target.actual_staple_type = source.actual_staple_type
	target.cook_time = source.cook_time
	target.ingredient_time_required = source.ingredient_time_required
	target.ready_window_seconds = source.ready_window_seconds
	target.staple_perfect_time = source.staple_perfect_time
	target.staple_overcook_time = source.staple_overcook_time
	target.order_patience_max = source.order_patience_max
	target.order_patience_current = source.order_patience_current
	target.visible = true
	target.refresh_visuals()


func _clean_invalid_content() -> void:
	if content_bowl != null and not is_instance_valid(content_bowl):
		content_bowl = null


func _get_restaurant_manager() -> RestaurantGameManager:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager


func _ensure_visuals() -> void:
	if visual == null:
		visual = get_node_or_null("Visual") as Polygon2D
	if label == null:
		label = get_node_or_null("Label") as Label
	if visual == null:
		visual = Polygon2D.new()
		visual.name = "Visual"
		visual.polygon = PackedVector2Array([
			Vector2(-22, -16),
			Vector2(22, -16),
			Vector2(26, 10),
			Vector2(14, 22),
			Vector2(-14, 22),
			Vector2(-26, 10)
		])
		add_child(visual)
	if label == null:
		label = Label.new()
		label.name = "Label"
		label.position = Vector2(-38, -9)
		label.size = Vector2(76, 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 2)
		add_child(label)
