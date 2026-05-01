class_name SettlementWidgetsController
extends RefCounted


static func create_cat_feed_widgets(parent: Control) -> Dictionary:
	var result := {}

	var cat_feed_area := Panel.new()
	cat_feed_area.name = "CatFeedArea"
	cat_feed_area.size = Vector2(170, 145)
	cat_feed_area.z_index = 2
	cat_feed_area.mouse_filter = Control.MOUSE_FILTER_STOP
	cat_feed_area.set_script(preload("res://scenes/settlement/cat_feed_area.gd"))
	parent.add_child(cat_feed_area)
	result["cat_feed_area"] = cat_feed_area

	var cat_label := Label.new()
	cat_label.name = "CatLabel"
	cat_label.text = TextDB.get_text("UI_SETTLEMENT_CAT_LABEL")
	cat_label.position = Vector2(0, 18)
	cat_label.size = Vector2(170, 66)
	cat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cat_label.add_theme_font_size_override("font_size", 28)
	cat_feed_area.add_child(cat_label)

	var cat_hint := Label.new()
	cat_hint.name = "CatHintLabel"
	cat_hint.text = TextDB.get_text("UI_SETTLEMENT_CAT_HINT")
	cat_hint.position = Vector2(0, 88)
	cat_hint.size = Vector2(170, 42)
	cat_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cat_hint.add_theme_font_size_override("font_size", 12)
	cat_feed_area.add_child(cat_hint)

	var cat_reaction_label := Label.new()
	cat_reaction_label.name = "CatReactionLabel"
	cat_reaction_label.text = ""
	cat_reaction_label.size = Vector2(180, 34)
	cat_reaction_label.z_index = 5
	cat_reaction_label.visible = false
	cat_reaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_reaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cat_reaction_label.add_theme_font_size_override("font_size", 18)
	parent.add_child(cat_reaction_label)
	result["cat_reaction_label"] = cat_reaction_label

	var leftover_food_panel := Panel.new()
	leftover_food_panel.name = "LeftoverFoodPanel"
	leftover_food_panel.size = Vector2(540, 74)
	leftover_food_panel.z_index = 2
	parent.add_child(leftover_food_panel)
	result["leftover_food_panel"] = leftover_food_panel

	var leftover_food_container := HBoxContainer.new()
	leftover_food_container.name = "LeftoverFoodContainer"
	leftover_food_container.position = Vector2(14, 19)
	leftover_food_container.size = Vector2(512, 42)
	leftover_food_container.add_theme_constant_override("separation", 12)
	leftover_food_panel.add_child(leftover_food_container)
	result["leftover_food_container"] = leftover_food_container

	return result


static func create_leftover_food_button(item_id: String, item_name: String, amount: int) -> Button:
	var button := Button.new()
	button.set_script(preload("res://scenes/settlement/draggable_leftover_food_button.gd"))
	button.custom_minimum_size = Vector2(120, 36)
	button.size = Vector2(120, 36)
	button.call("setup", item_id, item_name, amount)
	return button


static func create_empty_leftover_label() -> Label:
	var empty_label := Label.new()
	empty_label.text = TextDB.get_text("UI_SETTLEMENT_CAT_NO_LEFTOVER")
	empty_label.size = Vector2(390, 34)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.add_theme_font_size_override("font_size", 14)
	return empty_label
