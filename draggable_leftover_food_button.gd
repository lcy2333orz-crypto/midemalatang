extends Button

var item_id: String = ""
var item_name: String = ""
var item_amount: int = 0


func setup(new_item_id: String, new_item_name: String, new_amount: int) -> void:
	item_id = new_item_id
	item_name = new_item_name
	item_amount = new_amount
	text = "%s x%d" % [item_name, item_amount]


func _get_drag_data(_at_position: Vector2):
	if item_id == "" or item_amount <= 0:
		return null

	var preview := Label.new()
	preview.text = text
	preview.size = Vector2(110, 36)
	preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview.add_theme_font_size_override("font_size", 16)

	set_drag_preview(preview)

	return {
		"drag_type": "leftover_food",
		"item_id": item_id,
		"item_name": item_name
	}
