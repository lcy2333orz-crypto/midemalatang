class_name DayGiftPanelController
extends RefCounted

var manager: Node = null
var layer: CanvasLayer = null
var panel: Panel = null


func bind(game_manager: Node) -> void:
	manager = game_manager


func is_open() -> bool:
	return layer != null and is_instance_valid(layer)


func open(gift_data: Dictionary, options: Array) -> void:
	if manager == null or not is_instance_valid(manager):
		return

	close()

	layer = CanvasLayer.new()
	layer.name = "DayGiftLayer"
	layer.layer = 120
	manager.add_child(layer)

	var viewport_size: Vector2 = manager.get_viewport().get_visible_rect().size

	panel = Panel.new()
	panel.name = "DayGiftPanel"
	panel.size = Vector2(720, 360)
	panel.position = Vector2(
		viewport_size.x * 0.5 - 360,
		viewport_size.y * 0.5 - 180
	)
	layer.add_child(panel)

	var title_label := Label.new()
	title_label.name = "DayGiftTitle"
	title_label.text = str(gift_data.get("display_name", TextDB.get_text("UI_DAY_GIFT_DEFAULT_TITLE")))
	title_label.position = Vector2(24, 18)
	title_label.size = Vector2(672, 34)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	panel.add_child(title_label)

	var desc_label := Label.new()
	desc_label.name = "DayGiftDesc"
	desc_label.text = TextDB.get_text("UI_DAY_GIFT_DESC")
	desc_label.position = Vector2(48, 58)
	desc_label.size = Vector2(624, 44)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 14)
	panel.add_child(desc_label)

	for i in range(options.size()):
		var option_data: Dictionary = options[i]
		var button := Button.new()
		button.name = "DayGiftOption%d" % i
		button.position = Vector2(42 + i * 226, 125)
		button.size = Vector2(196, 150)
		button.text = manager.get_day_gift_option_button_text(option_data)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(Callable(manager, "_on_day_gift_option_pressed").bind(i))
		panel.add_child(button)

	var close_button := Button.new()
	close_button.name = "DayGiftCloseButton"
	close_button.text = TextDB.get_text("UI_DAY_GIFT_CLOSE")
	close_button.position = Vector2(290, 300)
	close_button.size = Vector2(140, 38)
	close_button.pressed.connect(Callable(manager, "close_day_gift_choice_panel"))
	panel.add_child(close_button)


func close() -> void:
	if is_open():
		layer.queue_free()

	layer = null
	panel = null
