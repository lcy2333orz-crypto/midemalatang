class_name DayGiftPanelController
extends RefCounted

const DayGiftPanelScene = preload("res://scenes/ui/day_gift_panel.tscn")

var manager: Node = null
var callback_target = null
var layer: CanvasLayer = null
var panel: Panel = null


func bind(game_manager: Node, target = null) -> void:
	manager = game_manager
	callback_target = target
	if callback_target == null:
		callback_target = manager


func is_open() -> bool:
	return layer != null and is_instance_valid(layer)


func open(gift_data: Dictionary, options: Array) -> void:
	if manager == null or not is_instance_valid(manager):
		return

	close()

	layer = DayGiftPanelScene.instantiate() as CanvasLayer
	manager.add_child(layer)

	var viewport_size: Vector2 = manager.get_viewport().get_visible_rect().size

	panel = layer.get_node("DayGiftPanel") as Panel
	panel.position = Vector2(
		viewport_size.x * 0.5 - 360,
		viewport_size.y * 0.5 - 180
	)

	var title_label: Label = panel.get_node("DayGiftTitle") as Label
	title_label.text = str(gift_data.get("display_name", TextDB.get_text("UI_DAY_GIFT_DEFAULT_TITLE")))

	var desc_label: Label = panel.get_node("DayGiftDesc") as Label
	desc_label.text = TextDB.get_text("UI_DAY_GIFT_DESC")

	var option_nodes: Array = [
		panel.get_node("DayGiftOptions/DayGiftOption0") as Button,
		panel.get_node("DayGiftOptions/DayGiftOption1") as Button,
		panel.get_node("DayGiftOptions/DayGiftOption2") as Button
	]

	for i in range(option_nodes.size()):
		var button: Button = option_nodes[i]
		if i >= options.size():
			button.visible = false
			continue

		var option_data: Dictionary = options[i]
		button.visible = true
		button.text = callback_target.get_day_gift_option_button_text(option_data)
		button.pressed.connect(Callable(callback_target, "_on_day_gift_option_pressed").bind(i))

	var close_button: Button = panel.get_node("DayGiftCloseButton") as Button
	close_button.text = TextDB.get_text("UI_DAY_GIFT_CLOSE")
	close_button.pressed.connect(Callable(callback_target, "close_day_gift_choice_panel"))


func close() -> void:
	if is_open():
		layer.queue_free()

	layer = null
	panel = null
