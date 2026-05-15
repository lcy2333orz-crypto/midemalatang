class_name CookerStation
extends Node2D

const CookingPotScene = preload("res://scenes/gameplay/restaurant/cooking_pot.tscn")

@export var station_id: String = "CookerStation1"
@export var default_pot_id: String = ""

var active_pot: CookingPot = null
var active_bowl: OrderBowl = null
var holder_bowl: OrderBowl = null
var bowl: OrderBowl = null
var holder_position: Vector2 = Vector2(0, 34)
var pot_area: Node2D = null
var bowl_holder_area: Node2D = null
var status_label: Label = null


func _ready() -> void:
	_ensure_parts()
	_find_existing_pot()
	if active_pot == null:
		var pot: CookingPot = CookingPotScene.instantiate() as CookingPot
		pot.pot_id = default_pot_id if default_pot_id.strip_edges() != "" else station_id.replace("CookerStation", "Pot")
		place_pot(pot)
	_sync_compat_bowl()
	_update_status_label()


func _process(_delta: float) -> void:
	_ensure_parts()
	if active_pot != null and is_instance_valid(active_pot):
		active_pot.set_on_heat(true)
		active_pot.refresh_visual()
	_sync_compat_bowl()
	_update_status_label()


func has_pot() -> bool:
	return active_pot != null and is_instance_valid(active_pot)


func can_accept_pot() -> bool:
	return not has_pot()


func place_pot(pot: CookingPot) -> bool:
	_ensure_parts()
	if pot == null or not is_instance_valid(pot) or has_pot():
		return false
	active_pot = pot
	if pot.get_parent() != null:
		pot.get_parent().remove_child(pot)
	pot_area.add_child(pot)
	pot.position = Vector2.ZERO
	pot.z_index = 24
	pot.current_station = self
	pot.set_on_heat(true)
	_sync_compat_bowl()
	_update_status_label()
	return true


func take_pot() -> CookingPot:
	if not has_pot():
		return null
	var pot: CookingPot = active_pot
	active_pot = null
	pot.current_station = null
	pot.set_on_heat(false)
	_sync_compat_bowl()
	_update_status_label()
	return pot


func get_pot() -> CookingPot:
	if has_pot():
		return active_pot
	return null


func can_accept_bowl() -> bool:
	return has_pot() and active_pot.is_empty()


func add_bowl_to_pot(new_bowl: OrderBowl) -> bool:
	if not has_pot():
		return false
	if not active_pot.add_order_bowl(new_bowl):
		return false
	_sync_compat_bowl()
	_update_status_label()
	return true


func add_bowl(new_bowl: OrderBowl) -> bool:
	return add_bowl_to_pot(new_bowl)


func can_scoop_to_bowl(empty_bowl: OrderBowl) -> bool:
	return has_pot() and active_pot.can_scoop_to_empty_bowl(empty_bowl)


func scoop_to_bowl(empty_bowl: OrderBowl) -> bool:
	if not can_scoop_to_bowl(empty_bowl):
		return false
	var ok: bool = active_pot.scoop_to_empty_bowl(empty_bowl)
	_sync_compat_bowl()
	_update_status_label()
	return ok


func can_take_bowl() -> bool:
	return has_pot() and active_pot.content_bowl != null and active_pot.content_bowl.can_leave_cooker()


func take_bowl() -> OrderBowl:
	if not can_take_bowl():
		return null
	var result: OrderBowl = active_pot.clear_content()
	if result != null:
		result.visible = true
		result.set_full_order_visual()
	_sync_compat_bowl()
	_update_status_label()
	return result


func clear_overcooked_content() -> OrderBowl:
	if not has_pot() or not active_pot.has_overcooked_content():
		return null
	return clear_active_bowl()


func clear_overcooked_bowl() -> OrderBowl:
	return clear_overcooked_content()


func clear_active_bowl() -> OrderBowl:
	if not has_pot():
		return null
	var result: OrderBowl = active_pot.clear_content()
	if result != null:
		result.visible = true
	_sync_compat_bowl()
	_update_status_label()
	return result


func get_active_order_id() -> int:
	if active_bowl == null:
		return 0
	return active_bowl.order_id


func get_status_text() -> String:
	if not has_pot():
		return "NO POT"
	return active_pot.get_content_status_text()


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


func _find_existing_pot() -> void:
	for child in pot_area.get_children():
		var pot: CookingPot = child as CookingPot
		if pot != null:
			active_pot = pot
			active_pot.current_station = self
			active_pot.set_on_heat(true)
			return


func _sync_compat_bowl() -> void:
	if has_pot() and active_pot.content_bowl != null and is_instance_valid(active_pot.content_bowl):
		active_bowl = active_pot.content_bowl
	else:
		active_bowl = null
	holder_bowl = active_bowl
	bowl = active_bowl


func _update_status_label() -> void:
	_ensure_parts()
	status_label.text = get_status_text()
