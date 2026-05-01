class_name SupplierOrderPanelController
extends RefCounted

var manager = null
var supplier_system = null

var layer: CanvasLayer = null
var panel: Panel = null
var status_label: Label = null
var buttons: Array[Button] = []


func bind(game_manager: Node, system) -> void:
	manager = game_manager
	supplier_system = system


func is_open() -> bool:
	return layer != null and is_instance_valid(layer)


func open() -> void:
	if is_open():
		refresh()
		return

	layer = CanvasLayer.new()
	layer.name = "SupplierOrderLayer"
	layer.layer = 90
	manager.add_child(layer)

	var viewport_size := manager.get_viewport().get_visible_rect().size

	panel = Panel.new()
	panel.name = "SupplierOrderPanel"
	panel.size = Vector2(640, 430)
	panel.position = Vector2(viewport_size.x * 0.5 - 320, viewport_size.y * 0.5 - 215)
	layer.add_child(panel)

	var title_label := Label.new()
	title_label.name = "SupplierOrderTitle"
	title_label.text = "早市供货商"
	title_label.position = Vector2(24, 14)
	title_label.size = Vector2(592, 32)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	panel.add_child(title_label)

	var desc_label := Label.new()
	desc_label.name = "SupplierOrderDesc"
	desc_label.text = "开业前可以批量订货。食材和主食都按篮/箱送达；开业后供货商就不接单了。"
	desc_label.position = Vector2(36, 48)
	desc_label.size = Vector2(568, 44)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(desc_label)

	status_label = Label.new()
	status_label.name = "SupplierOrderStatus"
	status_label.position = Vector2(34, 92)
	status_label.size = Vector2(572, 108)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(status_label)

	buttons.clear()

	var item_ids := RunSetupData.get_supplier_order_item_ids()
	var package_options := RunSetupData.get_supplier_package_options()
	var start_x := 34
	var start_y := 210
	var button_w := 112
	var button_h := 48
	var gap_x := 8
	var gap_y := 10
	var button_index := 0

	for item_id in item_ids:
		for package_data in package_options:
			if typeof(package_data) != TYPE_DICTIONARY:
				continue

			var amount := int(package_data.get("amount", 1))
			var package_id := str(package_data.get("id", "package"))
			var package_name := str(package_data.get("name", "一批"))
			var button := Button.new()
			button.name = "Order_%s_%s_Button" % [item_id, package_id]
			button.position = Vector2(
				start_x + (button_index % 5) * (button_w + gap_x),
				start_y + int(button_index / 5) * (button_h + gap_y)
			)
			button.size = Vector2(button_w, button_h)
			button.mouse_filter = Control.MOUSE_FILTER_STOP
			button.set_meta("item_id", item_id)
			button.set_meta("amount", amount)
			button.set_meta("package_name", package_name)
			button.pressed.connect(supplier_system.place_order.bind(item_id, amount))
			panel.add_child(button)
			buttons.append(button)
			button_index += 1

	var close_button := Button.new()
	close_button.name = "SupplierOrderCloseButton"
	close_button.text = "关闭"
	close_button.position = Vector2(250, 370)
	close_button.size = Vector2(140, 42)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(supplier_system.close_panel)
	panel.add_child(close_button)

	refresh()


func refresh() -> void:
	if panel == null:
		return

	if status_label != null:
		var lines: Array[String] = []
		lines.append("当前资金：%d" % manager.money)
		lines.append("生食材：%s" % manager.get_raw_stock_text())
		lines.append("主食库存：%s" % manager.get_staple_stock_text())

		if supplier_system.supplier_orders.is_empty():
			lines.append("待送达：无")
		else:
			lines.append("待送达：")
			for order_data in supplier_system.supplier_orders:
				if typeof(order_data) != TYPE_DICTIONARY:
					continue
				var order_items: Dictionary = order_data.get("items", {})
				var time_left := float(order_data.get("time_left", 0.0))
				lines.append("- %s，约 %.1f 秒后送达" % [
					manager.get_items_text(order_items),
					time_left
				])
		status_label.text = "\n".join(lines)

	for button in buttons:
		if button == null or not is_instance_valid(button):
			continue

		var item_id := str(button.get_meta("item_id", ""))
		var amount := int(button.get_meta("amount", 1))
		var package_name := str(button.get_meta("package_name", "一批"))
		if item_id == "":
			continue

		var price := RunSetupData.get_supplier_order_price(item_id, amount)
		var current_amount := 0
		if RunSetupData.is_staple_item(item_id):
			current_amount = int(manager.staple_stock.get(item_id, 0))
		else:
			current_amount = int(manager.raw_stock.get(item_id, 0))

		var pending_amount := supplier_system.get_pending_amount(item_id)
		var display_name := manager.get_ingredient_display_name(item_id)

		if pending_amount > 0:
			button.text = "%s %s x%d\n%d金｜库%d 待%d" % [
				display_name,
				package_name,
				amount,
				price,
				current_amount,
				pending_amount
			]
		else:
			button.text = "%s %s x%d\n%d金｜库存%d" % [
				display_name,
				package_name,
				amount,
				price,
				current_amount
			]

		button.disabled = manager.money < price or not supplier_system.can_use_ordering()


func close() -> void:
	if layer != null and is_instance_valid(layer):
		layer.queue_free()

	layer = null
	panel = null
	status_label = null
	buttons.clear()
