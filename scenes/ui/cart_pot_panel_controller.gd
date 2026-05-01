class_name CartPotPanelController
extends RefCounted

var manager = null
var cooking_system = null

var layer: CanvasLayer = null
var panel: Panel = null
var status_label: Label = null
var row_labels: Dictionary = {}
var minus_buttons: Dictionary = {}
var plus_buttons: Dictionary = {}
var max_buttons: Dictionary = {}


func bind(game_manager: Node, system) -> void:
	manager = game_manager
	cooking_system = system


func is_open() -> bool:
	return layer != null and is_instance_valid(layer)


func open() -> void:
	if is_open():
		refresh()
		return

	layer = CanvasLayer.new()
	layer.name = "CartPotLayer"
	layer.layer = 95
	manager.add_child(layer)

	var viewport_size: Vector2 = manager.get_viewport().get_visible_rect().size

	panel = Panel.new()
	panel.name = "CartPotPanel"
	panel.size = Vector2(720, 430)
	panel.position = Vector2(viewport_size.x * 0.5 - 360, viewport_size.y * 0.5 - 215)
	layer.add_child(panel)

	var title_label := Label.new()
	title_label.name = "CartPotTitle"
	title_label.text = "大锅：批量煮配菜"
	title_label.position = Vector2(24, 14)
	title_label.size = Vector2(672, 32)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	panel.add_child(title_label)

	var desc_label := Label.new()
	desc_label.name = "CartPotDesc"
	desc_label.text = "选择这次要加入大锅的配菜数量。关上锅盖后，如果本次准备不为空，就会自动开始煮。"
	desc_label.position = Vector2(40, 48)
	desc_label.size = Vector2(640, 42)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(desc_label)

	status_label = Label.new()
	status_label.name = "CartPotStatus"
	status_label.position = Vector2(36, 94)
	status_label.size = Vector2(648, 96)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(status_label)

	row_labels.clear()
	minus_buttons.clear()
	plus_buttons.clear()
	max_buttons.clear()

	var item_ids: Array = cooking_system.get_cart_pot_ingredient_ids()
	var start_y: int = 205
	var row_h: int = 46

	for i in range(item_ids.size()):
		var item_id: String = str(item_ids[i])
		var row_y: int = start_y + i * row_h

		var row_label := Label.new()
		row_label.name = "CartPot_%s_Label" % item_id
		row_label.position = Vector2(40, row_y)
		row_label.size = Vector2(360, 34)
		row_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row_label.add_theme_font_size_override("font_size", 15)
		panel.add_child(row_label)
		row_labels[item_id] = row_label

		var minus_button := Button.new()
		minus_button.name = "CartPot_%s_MinusButton" % item_id
		minus_button.text = "-"
		minus_button.position = Vector2(420, row_y)
		minus_button.size = Vector2(48, 34)
		minus_button.pressed.connect(cooking_system._on_cart_pot_minus_pressed.bind(item_id))
		panel.add_child(minus_button)
		minus_buttons[item_id] = minus_button

		var plus_button := Button.new()
		plus_button.name = "CartPot_%s_PlusButton" % item_id
		plus_button.text = "+"
		plus_button.position = Vector2(478, row_y)
		plus_button.size = Vector2(48, 34)
		plus_button.pressed.connect(cooking_system._on_cart_pot_plus_pressed.bind(item_id))
		panel.add_child(plus_button)
		plus_buttons[item_id] = plus_button

		var max_button := Button.new()
		max_button.name = "CartPot_%s_MaxButton" % item_id
		max_button.text = "最大"
		max_button.position = Vector2(538, row_y)
		max_button.size = Vector2(72, 34)
		max_button.pressed.connect(cooking_system._on_cart_pot_max_pressed.bind(item_id))
		panel.add_child(max_button)
		max_buttons[item_id] = max_button

	var close_button := Button.new()
	close_button.name = "CartPotCloseButton"
	close_button.text = "盖上锅盖"
	close_button.position = Vector2(290, 360)
	close_button.size = Vector2(140, 42)
	close_button.pressed.connect(cooking_system.close_cart_pot_panel_and_auto_start)
	panel.add_child(close_button)

	refresh()


func request_refresh() -> void:
	if panel == null or not is_instance_valid(panel):
		return
	manager.call_deferred("refresh_cart_pot_panel")


func refresh() -> void:
	if panel == null:
		return

	if status_label != null:
		var lines: Array[String] = []
		lines.append("大锅容量：%d / %d" % [
			cooking_system.get_cart_pot_total_capacity_with_selection(),
			cooking_system.cart_pot_capacity
		])
		lines.append("锅中熟配菜：%s" % manager.get_cooked_stock_text())

		if cooking_system.cart_pot_is_cooking:
			lines.append("正在煮：%s，剩余 %.1f 秒" % [
				manager.get_items_text(cooking_system.cart_pot_cooking_batch),
				max(cooking_system.cart_pot_time_left, 0.0)
			])
		else:
			lines.append("正在煮：无")

		if cooking_system.cart_pot_selection.is_empty():
			lines.append("本次准备：无")
		else:
			lines.append("本次准备：%s" % manager.get_items_text(cooking_system.cart_pot_selection))

		status_label.text = "\n".join(lines)

	var disabled_by_cooking := cooking_system.cart_pot_is_cooking

	for item_id in cooking_system.get_cart_pot_ingredient_ids():
		var item_key := str(item_id)
		var raw_amount := int(manager.raw_stock.get(item_key, 0))
		var cooked_amount := int(manager.cooked_stock.get(item_key, 0))
		var selected_amount := int(cooking_system.cart_pot_selection.get(item_key, 0))
		var display_name := manager.get_ingredient_display_name(item_key)

		if row_labels.has(item_key):
			var row_label: Label = row_labels[item_key]
			row_label.text = "%s 生 x%d 锅中熟 x%d 本次煮 x%d" % [
				display_name,
				raw_amount,
				cooked_amount,
				selected_amount
			]

		if minus_buttons.has(item_key):
			var minus_button: Button = minus_buttons[item_key]
			minus_button.disabled = disabled_by_cooking or selected_amount <= 0

		if plus_buttons.has(item_key):
			var plus_button: Button = plus_buttons[item_key]
			plus_button.disabled = not cooking_system.can_add_to_cart_pot_selection(item_key, 1)

		if max_buttons.has(item_key):
			var max_button: Button = max_buttons[item_key]
			max_button.disabled = (
				disabled_by_cooking
				or raw_amount <= selected_amount
				or cooking_system.get_cart_pot_available_capacity_for_selection() <= 0
			)


func close() -> void:
	if layer != null and is_instance_valid(layer):
		layer.queue_free()

	layer = null
	panel = null
	status_label = null
	row_labels.clear()
	minus_buttons.clear()
	plus_buttons.clear()
	max_buttons.clear()
