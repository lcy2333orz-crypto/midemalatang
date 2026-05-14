class_name WaitingOrderArea
extends Node2D

var bowls: Array[OrderBowl] = []
var slots: Array[Vector2] = [
	Vector2(-50, -18),
	Vector2(0, -18),
	Vector2(50, -18),
	Vector2(-25, 24),
	Vector2(25, 24)
]


func add_bowl(bowl: OrderBowl) -> bool:
	if bowl == null or bowls.has(bowl):
		return false
	if bowls.size() >= slots.size():
		return false

	bowls.append(bowl)
	bowl.status = OrderBowl.STATUS_WAITING
	bowl.detach_to_world(self, global_position + slots[bowls.size() - 1])
	bowl.refresh_visuals()
	return true


func take_first_bowl() -> OrderBowl:
	if bowls.is_empty():
		return null
	var bowl: OrderBowl = bowls.pop_front() as OrderBowl
	_reflow()
	return bowl


func remove_bowl(bowl: OrderBowl) -> void:
	if bowls.has(bowl):
		bowls.erase(bowl)
	_reflow()


func _reflow() -> void:
	for i in range(bowls.size()):
		var bowl: OrderBowl = bowls[i]
		if bowl != null and is_instance_valid(bowl):
			bowl.position = slots[i]
