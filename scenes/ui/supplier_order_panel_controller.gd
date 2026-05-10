class_name SupplierOrderPanelController
extends RefCounted

const SupplierOrderPanelScene = preload("res://scenes/ui/supplier_order_panel.tscn")

var manager = null
var supplier_system = null

var layer: CanvasLayer = null
var panel: Panel = null
var status_label: Label = null
var options_root: Control = null
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

	layer = SupplierOrderPanelScene.instantiate() as CanvasLayer
	manager.add_child(layer)

	var viewport_size: Vector2 = manager.get_viewport().get_visible_rect().size

	panel = layer.get_node("SupplierOrderPanel") as Panel
	panel.position = Vector2(viewport_size.x * 0.5 - 320, viewport_size.y * 0.5 - 215)

	var title_label: Label = panel.get_node("SupplierOrderTitle") as Label
	title_label.text = TextDB.get_text("UI_SUPPLIER_ORDER_TITLE")

	var desc_label: Label = panel.get_node("SupplierOrderDesc") as Label
	desc_label.text = TextDB.get_text("UI_SUPPLIER_ORDER_DESC")

	status_label = panel.get_node("SupplierOrderStatus") as Label
	options_root = panel.get_node("SupplierOrderOptions") as Control

	buttons.clear()

	var item_ids: Array[String] = RunSetupData.get_supplier_order_item_ids()
	var package_options: Array = RunSetupData.get_supplier_package_options()
	var start_x: int = 0
	var start_y: int = 0
	var button_w: int = 112
	var button_h: int = 48
	var gap_x: int = 8
	var gap_y: int = 10
	var button_index: int = 0

	for item_id in item_ids:
		for package_data in package_options:
			if typeof(package_data) != TYPE_DICTIONARY:
				continue

			var amount: int = int(package_data.get("amount", 1))
			var package_id: String = str(package_data.get("id", "package"))
			var package_name: String = _get_package_name(package_data)
			var button: Button = Button.new()
			button.name = "Order_%s_%s_Button" % [item_id, package_id]
			button.position = Vector2(
				start_x + (button_index % 5) * (button_w + gap_x),
				start_y + int(button_index / 5) * (button_h + gap_y)
			)
			button.size = Vector2(button_w, button_h)
			button.mouse_filter = Control.MOUSE_FILTER_STOP
			button.set_meta("item_id", item_id)
			button.set_meta("amount", amount)
			button.set_meta("package_id", package_id)
			button.set_meta("package_name", package_name)
			button.pressed.connect(supplier_system.place_order.bind(item_id, amount))
			options_root.add_child(button)
			buttons.append(button)
			button_index += 1

	var close_button: Button = panel.get_node("SupplierOrderCloseButton") as Button
	close_button.text = TextDB.get_text("UI_SUPPLIER_ORDER_CLOSE")
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(supplier_system.close_panel)

	refresh()


func refresh() -> void:
	if panel == null:
		return

	if status_label != null:
		var lines: Array[String] = []
		lines.append(TextDB.get_text("UI_SUPPLIER_MONEY") % manager.money)
		lines.append(TextDB.get_text("UI_SUPPLIER_RAW_STOCK") % manager.inventory_system.get_raw_stock_text())
		lines.append(TextDB.get_text("UI_SUPPLIER_STAPLE_STOCK") % manager.inventory_system.get_staple_stock_text())
		if RunSetupData.is_tutorial_day():
			lines.append(TextDB.get_text("UI_SUPPLIER_NOODLE_TUTORIAL_LOCKED"))
			lines.append(get_tutorial_supplier_status_text())

		if supplier_system.supplier_orders.is_empty():
			lines.append(TextDB.get_text("UI_SUPPLIER_PENDING_NONE"))
		else:
			lines.append(TextDB.get_text("UI_SUPPLIER_PENDING_HEADER"))
			for order_data in supplier_system.supplier_orders:
				if typeof(order_data) != TYPE_DICTIONARY:
					continue
				var order_items: Dictionary = order_data.get("items", {})
				var time_left: float = float(order_data.get("time_left", 0.0))
				lines.append(TextDB.get_text("UI_SUPPLIER_PENDING_LINE") % [
					manager.order_system.get_items_text(order_items),
					time_left
				])
		status_label.text = "\n".join(lines)

	for button in buttons:
		if button == null or not is_instance_valid(button):
			continue

		var item_id: String = str(button.get_meta("item_id", ""))
		var amount: int = int(button.get_meta("amount", 1))
		var package_id: String = str(button.get_meta("package_id", ""))
		var package_name: String = str(button.get_meta("package_name", TextDB.get_text("UI_SUPPLIER_PACKAGE_FALLBACK")))
		if item_id == "":
			continue

		var price: int = RunSetupData.get_supplier_order_price(item_id, amount)
		var current_amount: int = 0
		if RunSetupData.is_staple_item(item_id):
			current_amount = int(manager.staple_stock.get(item_id, 0))
		else:
			current_amount = int(manager.raw_stock.get(item_id, 0))

		var pending_amount: int = supplier_system.get_pending_amount(item_id)
		var display_name: String = TextDB.get_item_name(item_id)
		var blocked_by_tutorial: bool = supplier_system.has_method("is_order_blocked_by_tutorial") and supplier_system.is_order_blocked_by_tutorial(item_id, amount)

		if blocked_by_tutorial:
			button.text = TextDB.get_text("UI_SUPPLIER_BUTTON_TUTORIAL_LOCKED") % [
				display_name,
				get_tutorial_button_lock_text(item_id, package_id)
			]
		elif pending_amount > 0:
			button.text = TextDB.get_text("UI_SUPPLIER_BUTTON_PENDING") % [
				display_name,
				package_name,
				amount,
				price,
				current_amount,
				pending_amount
			]
		else:
			button.text = TextDB.get_text("UI_SUPPLIER_BUTTON") % [
				display_name,
				package_name,
				amount,
				price,
				current_amount
			]

		button.disabled = blocked_by_tutorial or manager.money < price or not supplier_system.can_use_ordering()


func get_tutorial_supplier_status_text() -> String:
	if supplier_system.are_tutorial_required_supplies_delivered():
		return TextDB.get_text("UI_SUPPLIER_TUTORIAL_SUPPLIES_DELIVERED")

	if supplier_system.are_tutorial_required_supplies_ordered():
		return TextDB.get_text("UI_SUPPLIER_TUTORIAL_SUPPLIES_ORDERED")

	var missing_names: Array[String] = supplier_system.get_tutorial_missing_supply_names(false)
	return TextDB.get_text("UI_SUPPLIER_TUTORIAL_BUY_EACH_BASKET") % ", ".join(missing_names)


func get_tutorial_button_lock_text(item_id: String, package_id: String) -> String:
	if item_id == "noodle":
		return TextDB.get_text("UI_SUPPLIER_NOODLE_TUTORIAL_LOCKED_SHORT")

	if package_id == "box":
		return TextDB.get_text("UI_SUPPLIER_BOX_TUTORIAL_LOCKED_SHORT")

	if supplier_system.has_tutorial_required_supply_ordered(item_id):
		return TextDB.get_text("UI_SUPPLIER_REQUIRED_TUTORIAL_ORDERED_SHORT")

	return TextDB.get_text("UI_SUPPLIER_TUTORIAL_LOCKED_SHORT")


func close() -> void:
	if layer != null and is_instance_valid(layer):
		layer.queue_free()

	layer = null
	panel = null
	status_label = null
	options_root = null
	buttons.clear()


func _get_package_name(package_data: Dictionary) -> String:
	var text_key: String = str(package_data.get("text_key", ""))

	if text_key != "":
		return TextDB.get_text(text_key)

	return str(package_data.get("name", TextDB.get_text("UI_SUPPLIER_PACKAGE_FALLBACK")))
