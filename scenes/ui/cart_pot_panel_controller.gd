class_name CartPotPanelController

extends RefCounted



var manager = null

var cooking_system = null



var layer: CanvasLayer = null

var panel: Panel = null

var status_label: Label = null

var capacity_grid: GridContainer = null

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

	panel.size = Vector2(720, 470)

	panel.position = Vector2(viewport_size.x * 0.5 - 360, viewport_size.y * 0.5 - 235)

	layer.add_child(panel)



	var title_label: Label = Label.new()

	title_label.name = "CartPotTitle"

	title_label.text = TextDB.get_text("UI_CART_POT_TITLE")

	title_label.position = Vector2(24, 14)

	title_label.size = Vector2(672, 32)

	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	title_label.add_theme_font_size_override("font_size", 22)

	panel.add_child(title_label)



	var desc_label: Label = Label.new()

	desc_label.name = "CartPotDesc"

	desc_label.text = TextDB.get_text("UI_CART_POT_DESC")

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

	status_label.size = Vector2(648, 80)

	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	status_label.add_theme_font_size_override("font_size", 13)

	panel.add_child(status_label)



	capacity_grid = GridContainer.new()

	capacity_grid.name = "CartPotCapacityGrid"

	capacity_grid.position = Vector2(40, 178)

	capacity_grid.size = Vector2(640, 44)

	capacity_grid.columns = 6

	capacity_grid.add_theme_constant_override("h_separation", 6)

	capacity_grid.add_theme_constant_override("v_separation", 6)

	panel.add_child(capacity_grid)



	row_labels.clear()

	minus_buttons.clear()

	plus_buttons.clear()

	max_buttons.clear()



	var item_ids: Array = cooking_system.get_cart_pot_ingredient_ids()

	var start_y: int = 235

	var row_h: int = 46



	for i in range(item_ids.size()):

		var item_id: String = str(item_ids[i])

		var row_y: int = start_y + i * row_h



		var row_label: Label = Label.new()

		row_label.name = "CartPot_%s_Label" % item_id

		row_label.position = Vector2(40, row_y)

		row_label.size = Vector2(360, 34)

		row_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		row_label.add_theme_font_size_override("font_size", 15)

		panel.add_child(row_label)

		row_labels[item_id] = row_label



		var minus_button: Button = Button.new()

		minus_button.name = "CartPot_%s_MinusButton" % item_id

		minus_button.text = "-"

		minus_button.position = Vector2(420, row_y)

		minus_button.size = Vector2(48, 34)

		minus_button.pressed.connect(cooking_system._on_cart_pot_minus_pressed.bind(item_id))

		panel.add_child(minus_button)

		minus_buttons[item_id] = minus_button



		var plus_button: Button = Button.new()

		plus_button.name = "CartPot_%s_PlusButton" % item_id

		plus_button.text = "+"

		plus_button.position = Vector2(478, row_y)

		plus_button.size = Vector2(48, 34)

		plus_button.pressed.connect(cooking_system._on_cart_pot_plus_pressed.bind(item_id))

		panel.add_child(plus_button)

		plus_buttons[item_id] = plus_button



		var max_button: Button = Button.new()

		max_button.name = "CartPot_%s_MaxButton" % item_id

		max_button.text = TextDB.get_text("UI_CART_POT_MAX")

		max_button.position = Vector2(538, row_y)

		max_button.size = Vector2(72, 34)

		max_button.pressed.connect(cooking_system._on_cart_pot_max_pressed.bind(item_id))

		panel.add_child(max_button)

		max_buttons[item_id] = max_button



	var close_button: Button = Button.new()

	close_button.name = "CartPotCloseButton"

	close_button.text = TextDB.get_text("UI_CART_POT_CLOSE")

	close_button.position = Vector2(290, 405)

	close_button.size = Vector2(140, 42)

	close_button.pressed.connect(cooking_system.close_cart_pot_panel_and_auto_start)

	panel.add_child(close_button)



	refresh()





func request_refresh() -> void:

	if panel == null or not is_instance_valid(panel):

		return

	cooking_system.call_deferred("refresh_cart_pot_panel")





func refresh() -> void:

	if panel == null:

		return



	if status_label != null:

		var lines: Array[String] = []

		lines.append(TextDB.get_text("UI_CART_POT_CAPACITY") % [

			cooking_system.get_cart_pot_total_capacity_with_selection(),

			cooking_system.cart_pot_capacity

		])

		lines.append(TextDB.get_text("UI_CART_POT_COOKED_STOCK") % manager.inventory_system.get_cooked_stock_text())



		if cooking_system.cart_pot_cooking_batches.is_empty():

			lines.append(TextDB.get_text("UI_CART_POT_BATCHES_NONE"))

		else:

			lines.append(TextDB.get_text("UI_CART_POT_BATCHES_HEADER"))

			for i in range(cooking_system.cart_pot_cooking_batches.size()):

				var batch: Dictionary = cooking_system.cart_pot_cooking_batches[i] as Dictionary

				var batch_items = batch.get("items", {})

				var batch_text: String = TextDB.get_text("UI_ITEM_NONE")



				if typeof(batch_items) == TYPE_DICTIONARY:

					batch_text = manager.order_system.get_items_text(batch_items as Dictionary)



				lines.append(TextDB.get_text("UI_CART_POT_BATCH_LINE") % [

					i + 1,

					batch_text,

					max(float(batch.get("time_left", 0.0)), 0.0)

				])



		if cooking_system.cart_pot_selection.is_empty():

			lines.append(TextDB.get_text("UI_CART_POT_SELECTION_NONE"))

		else:

			lines.append(TextDB.get_text("UI_CART_POT_SELECTION") % manager.order_system.get_items_text(cooking_system.cart_pot_selection))



		status_label.text = "\n".join(lines)



	_refresh_capacity_grid()



	for item_id in cooking_system.get_cart_pot_ingredient_ids():

		var item_key: String = str(item_id)

		var raw_amount: int = int(manager.raw_stock.get(item_key, 0))

		var cooked_amount: int = int(manager.cooked_stock.get(item_key, 0))

		var selected_amount: int = int(cooking_system.cart_pot_selection.get(item_key, 0))

		var display_name: String = TextDB.get_item_name(item_key)



		if row_labels.has(item_key):

			var row_label: Label = row_labels[item_key]

			row_label.text = TextDB.get_text("UI_CART_POT_ROW") % [

				display_name,

				raw_amount,

				cooked_amount,

				selected_amount

			]



		if minus_buttons.has(item_key):

			var minus_button: Button = minus_buttons[item_key]

			minus_button.disabled = selected_amount <= 0



		if plus_buttons.has(item_key):

			var plus_button: Button = plus_buttons[item_key]

			plus_button.disabled = not cooking_system.can_add_to_cart_pot_selection(item_key, 1)



		if max_buttons.has(item_key):

			var max_button: Button = max_buttons[item_key]

			max_button.disabled = (

				raw_amount <= selected_amount

				or cooking_system.get_cart_pot_available_capacity_for_selection() <= 0

			)





func close() -> void:

	if layer != null and is_instance_valid(layer):

		layer.queue_free()



	layer = null

	panel = null

	status_label = null

	capacity_grid = null

	row_labels.clear()

	minus_buttons.clear()

	plus_buttons.clear()

	max_buttons.clear()





func _refresh_capacity_grid() -> void:

	if capacity_grid == null:

		return



	var capacity: int = max(int(cooking_system.cart_pot_capacity), 0)

	var used_capacity: int = clamp(

		int(cooking_system.get_cart_pot_total_capacity_with_selection()),

		0,

		capacity

	)



	if capacity > 6:

		capacity_grid.columns = 6

	else:

		capacity_grid.columns = max(capacity, 1)



	_ensure_capacity_cells(capacity)



	for i in range(capacity_grid.get_child_count()):

		var cell: ColorRect = capacity_grid.get_child(i) as ColorRect

		if cell == null:

			continue



		if i < used_capacity:

			cell.color = Color(0.96, 0.44, 0.18, 1)

		else:

			cell.color = Color(0.18, 0.18, 0.18, 0.28)





func _ensure_capacity_cells(capacity: int) -> void:

	while capacity_grid.get_child_count() > capacity:

		var last_index: int = capacity_grid.get_child_count() - 1

		var child: Node = capacity_grid.get_child(last_index)

		capacity_grid.remove_child(child)

		child.queue_free()



	while capacity_grid.get_child_count() < capacity:

		var cell: ColorRect = ColorRect.new()

		cell.custom_minimum_size = Vector2(42, 16)

		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE

		capacity_grid.add_child(cell)
