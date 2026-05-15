class_name SurfaceSlot
extends Node2D

@export var slot_id: String = ""
@export var slot_label: String = ""
@export var is_takeout_pickup_slot: bool = false

var stored_bowl: OrderBowl = null


func _ready() -> void:
	refresh_visual()


func is_empty() -> bool:
	if stored_bowl != null and not is_instance_valid(stored_bowl):
		stored_bowl = null
		refresh_visual()
	return stored_bowl == null


func can_store_bowl(bowl: OrderBowl) -> bool:
	return bowl != null and is_instance_valid(bowl) and is_empty()


func store_bowl(bowl: OrderBowl) -> bool:
	if not can_store_bowl(bowl):
		return false

	stored_bowl = bowl
	if bowl.get_parent() != null:
		bowl.get_parent().remove_child(bowl)
	add_child(bowl)
	bowl.position = Vector2(0, -6)
	bowl.z_index = 20
	bowl.set_full_order_visual()
	refresh_visual()
	return true


func take_bowl() -> OrderBowl:
	if is_empty():
		refresh_visual()
		return null

	var bowl: OrderBowl = stored_bowl
	stored_bowl = null
	refresh_visual()
	return bowl


func remove_bowl_if_matches(bowl: OrderBowl) -> void:
	if stored_bowl == bowl:
		stored_bowl = null
		refresh_visual()


func get_stored_bowl() -> OrderBowl:
	if stored_bowl != null and not is_instance_valid(stored_bowl):
		stored_bowl = null
		refresh_visual()
	return stored_bowl


func refresh_visual() -> void:
	var label: Label = get_node_or_null("Label") as Label
	if label == null:
		return

	if stored_bowl != null and not is_instance_valid(stored_bowl):
		stored_bowl = null

	if stored_bowl == null:
		label.text = slot_label if slot_label.strip_edges() != "" else slot_id
	else:
		label.text = "#%03d" % stored_bowl.order_id
