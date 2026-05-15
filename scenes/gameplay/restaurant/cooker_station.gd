class_name CookerStation
extends Node2D

@export var station_id: String = "CookerStation1"

var active_bowl: OrderBowl = null
var holder_bowl: OrderBowl = null
var bowl: OrderBowl = null
var holder_position: Vector2 = Vector2(0, 34)
var pot_area: Node2D = null
var bowl_holder_area: Node2D = null
var status_label: Label = null


func _process(delta: float) -> void:
	_ensure_parts()
	if active_bowl != null and is_instance_valid(active_bowl):
		active_bowl.update_cooking(delta)
	_update_status_label()


func can_accept_bowl() -> bool:
	return active_bowl == null


func add_bowl(new_bowl: OrderBowl) -> bool:
	_ensure_parts()
	if new_bowl == null or active_bowl != null:
		return false

	active_bowl = new_bowl
	holder_bowl = new_bowl
	bowl = new_bowl
	active_bowl.status = OrderBowl.STATUS_COOKING
	active_bowl.cook_time = 0.0
	active_bowl.set_empty_holder_visual()
	active_bowl.detach_to_world(self, bowl_holder_area.global_position)
	active_bowl.z_index = 30
	_update_status_label()
	return true


func can_take_bowl() -> bool:
	return active_bowl != null and active_bowl.can_leave_cooker()


func take_bowl() -> OrderBowl:
	if not can_take_bowl():
		return null

	var result: OrderBowl = active_bowl
	result.set_full_order_visual()
	active_bowl = null
	holder_bowl = null
	bowl = null
	_update_status_label()
	return result


func clear_overcooked_bowl() -> OrderBowl:
	if active_bowl == null or not active_bowl.is_overcooked():
		return null

	return clear_active_bowl()


func clear_active_bowl() -> OrderBowl:
	if active_bowl == null:
		return null

	var result: OrderBowl = active_bowl
	active_bowl = null
	holder_bowl = null
	bowl = null
	_update_status_label()
	return result


func get_active_order_id() -> int:
	if active_bowl == null:
		return 0
	return active_bowl.order_id


func get_status_text() -> String:
	if active_bowl == null:
		return "空锅"
	return active_bowl.get_cooker_timer_text()


func _ensure_parts() -> void:
	if pot_area == null:
		pot_area = get_node_or_null("PotArea") as Node2D
	if bowl_holder_area == null:
		bowl_holder_area = get_node_or_null("BowlHolderArea") as Node2D
	if status_label == null:
		status_label = get_node_or_null("StatusLabel") as Label

	if pot_area == null:
		pot_area = Node2D.new()
		pot_area.name = "PotArea"
		add_child(pot_area)

	if bowl_holder_area == null:
		bowl_holder_area = Node2D.new()
		bowl_holder_area.name = "BowlHolderArea"
		bowl_holder_area.position = holder_position
		add_child(bowl_holder_area)

	if status_label == null:
		status_label = Label.new()
		status_label.name = "StatusLabel"
		status_label.position = Vector2(-42, -68)
		status_label.size = Vector2(84, 22)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status_label.add_theme_font_size_override("font_size", 13)
		status_label.add_theme_color_override("font_color", Color.BLACK)
		status_label.add_theme_color_override("font_outline_color", Color.WHITE)
		status_label.add_theme_constant_override("outline_size", 3)
		add_child(status_label)


func _update_status_label() -> void:
	_ensure_parts()
	status_label.text = get_status_text()
