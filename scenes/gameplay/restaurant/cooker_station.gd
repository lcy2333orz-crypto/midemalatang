class_name CookerStation
extends Node2D

@export var station_id: String = "CookerStation1"

var bowl: OrderBowl = null
var slot_position: Vector2 = Vector2(0, -18)


func _process(delta: float) -> void:
	if bowl != null and is_instance_valid(bowl):
		bowl.update_cooking(delta)


func can_accept_bowl() -> bool:
	return bowl == null


func add_bowl(new_bowl: OrderBowl) -> bool:
	if new_bowl == null or bowl != null:
		return false
	bowl = new_bowl
	bowl.status = OrderBowl.STATUS_COOKING
	bowl.cook_time = 0.0
	bowl.detach_to_world(self, global_position + slot_position)
	bowl.refresh_visuals()
	return true


func can_take_bowl() -> bool:
	return bowl != null and bowl.can_leave_cooker()


func take_bowl() -> OrderBowl:
	if not can_take_bowl():
		return null
	var result: OrderBowl = bowl
	bowl = null
	return result
