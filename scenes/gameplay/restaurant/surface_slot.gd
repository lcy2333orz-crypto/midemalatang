class_name SurfaceSlot
extends Node2D

@export var slot_id: String = ""
@export var slot_label: String = ""
@export var is_takeout_pickup_slot: bool = false

var stored_item: Node2D = null
var stored_bowl: OrderBowl = null


func _ready() -> void:
	refresh_visual()


func is_empty() -> bool:
	_clean_invalid_item()
	return stored_item == null


func can_store_item(item: Node2D) -> bool:
	return item != null and is_instance_valid(item) and is_empty() and (item is OrderBowl or item is CookingPot)


func store_item(item: Node2D) -> bool:
	if not can_store_item(item):
		return false
	stored_item = item
	stored_bowl = item as OrderBowl
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	add_child(item)
	item.position = Vector2(0, -6)
	item.z_index = 20
	var pot: CookingPot = item as CookingPot
	if pot != null:
		pot.set_on_heat(false)
		pot.current_station = null
		pot.refresh_visual()
	var bowl: OrderBowl = item as OrderBowl
	if bowl != null:
		bowl.visible = true
		if bowl.needs_refill:
			bowl.refresh_visuals()
		elif bowl.is_empty_holder:
			bowl.set_empty_holder_visual()
		else:
			bowl.set_full_order_visual()
	refresh_visual()
	return true


func take_item() -> Node2D:
	if is_empty():
		refresh_visual()
		return null
	var item: Node2D = stored_item
	stored_item = null
	stored_bowl = null
	refresh_visual()
	return item


func get_stored_item() -> Node2D:
	_clean_invalid_item()
	return stored_item


func get_stored_bowl() -> OrderBowl:
	_clean_invalid_item()
	return stored_item as OrderBowl


func get_stored_pot() -> CookingPot:
	_clean_invalid_item()
	return stored_item as CookingPot


func remove_item_if_matches(item: Node2D) -> void:
	if stored_item == item:
		stored_item = null
		stored_bowl = null
		refresh_visual()


func can_store_bowl(bowl: OrderBowl) -> bool:
	return can_store_item(bowl)


func store_bowl(bowl: OrderBowl) -> bool:
	return store_item(bowl)


func take_bowl() -> OrderBowl:
	var bowl: OrderBowl = get_stored_bowl()
	if bowl == null:
		return null
	take_item()
	return bowl


func remove_bowl_if_matches(bowl: OrderBowl) -> void:
	remove_item_if_matches(bowl)


func refresh_visual() -> void:
	var label: Label = get_node_or_null("Label") as Label
	if label == null:
		return

	_clean_invalid_item()

	if stored_item == null:
		label.text = slot_label if slot_label.strip_edges() != "" else slot_id
		return

	var bowl: OrderBowl = stored_item as OrderBowl
	if bowl != null:
		if bowl.needs_refill:
			label.text = "待补配 #%03d" % bowl.order_id
		else:
			label.text = "空碗 #%03d" % bowl.order_id if bowl.is_empty_holder else "#%03d" % bowl.order_id
		return

	var pot: CookingPot = stored_item as CookingPot
	if pot != null:
		label.text = pot.get_content_status_text()
		return

	label.text = slot_label if slot_label.strip_edges() != "" else slot_id


func _clean_invalid_item() -> void:
	if stored_item != null and not is_instance_valid(stored_item):
		stored_item = null
		stored_bowl = null
	if stored_bowl != null and not is_instance_valid(stored_bowl):
		stored_bowl = null
	if stored_item == null:
		stored_bowl = null
