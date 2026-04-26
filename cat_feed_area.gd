extends Panel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var settlement = get_tree().get_first_node_in_group("settlement_result")

			if settlement != null and settlement.has_method("pet_settlement_cat"):
				settlement.pet_settlement_cat()
				accept_event()


func _can_drop_data(_at_position: Vector2, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false

	return str(data.get("drag_type", "")) == "leftover_food"


func _drop_data(_at_position: Vector2, data) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return

	var settlement = get_tree().get_first_node_in_group("settlement_result")

	if settlement == null:
		return

	if not settlement.has_method("feed_cat_with_leftover_food"):
		return

	settlement.feed_cat_with_leftover_food(str(data.get("item_id", "")))
