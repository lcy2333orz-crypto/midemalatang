class_name SupplierSystem
extends RefCounted

const SupplierOrderPanelControllerScript = preload("res://scenes/ui/supplier_order_panel_controller.gd")

var manager = null
var panel_controller: SupplierOrderPanelController = null

var supplier_orders: Array = []
var supplier_order_sequence_id: int = 0


func bind(game_manager: Node) -> void:
	manager = game_manager
	panel_controller = SupplierOrderPanelControllerScript.new()
	panel_controller.bind(manager, self)


func clear_day_state() -> void:
	close_panel()
	supplier_orders.clear()
	supplier_order_sequence_id = 0


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	if manager == null or not is_instance_valid(manager):
		warnings.append("SupplierSystem is not bound to a valid GameManager.")
		return warnings

	if typeof(supplier_orders) != TYPE_ARRAY:
		warnings.append("SupplierSystem: supplier_orders is not an Array.")

	for order_data in supplier_orders:
		if typeof(order_data) != TYPE_DICTIONARY:
			warnings.append("SupplierSystem: supplier_orders contains a non-Dictionary entry.")
			continue

		if typeof(order_data.get("items", {})) != TYPE_DICTIONARY:
			warnings.append("SupplierSystem: supplier order items are not a Dictionary.")

		if float(order_data.get("time_left", 0.0)) < 0.0:
			warnings.append("SupplierSystem: supplier order has negative time_left.")

	return warnings


func can_use_ordering() -> bool:
	if manager.has_round_finished:
		return false

	if manager.is_round_closing:
		return false

	if manager.is_cleanup_phase:
		return false

	if manager.is_open_for_business:
		return false

	if manager.has_opened_for_business_today:
		return false

	return true


func open_panel() -> void:
	if not can_use_ordering():
		print("The regular supplier only accepts orders before opening. After opening, use EmergencyShop for emergency restock.")
		manager.gameplay_hud_system.show_storage_stock_only()
		return

	panel_controller.open()


func refresh_panel() -> void:
	panel_controller.refresh()


func close_panel() -> void:
	panel_controller.close()


func get_pending_amount(item_id: String) -> int:
	var total: int = 0

	for order_data in supplier_orders:
		if typeof(order_data) != TYPE_DICTIONARY:
			continue

		var items = order_data.get("items", {})

		if typeof(items) != TYPE_DICTIONARY:
			continue

		total += int(items.get(item_id, 0))

	return total


func place_order(item_id: String, amount: int = 1) -> void:
	if not can_use_ordering():
		print("The regular supplier only accepts orders before opening.")
		refresh_panel()
		return

	if is_order_blocked_by_tutorial(item_id, amount):
		print("Tutorial supplier order blocked: ", item_id, " amount=", amount)
		refresh_panel()
		return

	var price: int = RunSetupData.get_supplier_order_price(item_id, amount)

	if not manager.economy_system.spend_money(price):
		print("Supplier order failed. Not enough money.")
		refresh_panel()
		return

	supplier_order_sequence_id += 1

	var order_data: Dictionary = {
		"order_id": "supplier_order_%d" % supplier_order_sequence_id,
		"items": {
			item_id: amount
		},
		"time_left": RunSetupData.get_supplier_delivery_seconds()
	}

	supplier_orders.append(order_data)

	print("Supplier order placed: ", order_data)
	print("Supplier order cost: ", price)

	refresh_panel()


func is_item_blocked_by_tutorial(item_id: String) -> bool:
	return RunSetupData.is_tutorial_day() and item_id == "noodle"


func is_order_blocked_by_tutorial(item_id: String, amount: int) -> bool:
	if not RunSetupData.is_tutorial_day():
		return false

	if is_item_blocked_by_tutorial(item_id):
		return true

	if amount != get_tutorial_required_supply_amount():
		return true

	if not get_tutorial_required_supply_item_ids().has(item_id):
		return true

	return has_tutorial_required_supply_ordered(item_id)


func get_tutorial_required_supply_amount() -> int:
	return 10


func get_tutorial_required_supply_item_ids() -> Array[String]:
	return [
		"spinach",
		"potato_slice",
		"tofu_puff",
		"glass_noodle"
	]


func has_tutorial_required_supply_ordered(item_id: String) -> bool:
	return get_available_and_pending_amount(item_id) >= get_tutorial_required_supply_amount()


func has_tutorial_required_supply_delivered(item_id: String) -> bool:
	return get_current_stock_amount(item_id) >= get_tutorial_required_supply_amount()


func are_tutorial_required_supplies_ordered() -> bool:
	if not RunSetupData.is_tutorial_day():
		return true

	for item_id in get_tutorial_required_supply_item_ids():
		if not has_tutorial_required_supply_ordered(item_id):
			return false

	return true


func are_tutorial_required_supplies_delivered() -> bool:
	if not RunSetupData.is_tutorial_day():
		return true

	for item_id in get_tutorial_required_supply_item_ids():
		if not has_tutorial_required_supply_delivered(item_id):
			return false

	return true


func get_tutorial_missing_supply_names(require_delivered: bool = false) -> Array[String]:
	var missing_names: Array[String] = []

	for item_id in get_tutorial_required_supply_item_ids():
		var is_ready: bool = has_tutorial_required_supply_delivered(item_id) if require_delivered else has_tutorial_required_supply_ordered(item_id)
		if not is_ready:
			missing_names.append(TextDB.get_item_name(item_id))

	return missing_names


func get_current_stock_amount(item_id: String) -> int:
	if RunSetupData.is_staple_item(item_id):
		return int(manager.staple_stock.get(item_id, 0))

	return int(manager.raw_stock.get(item_id, 0))


func get_available_and_pending_amount(item_id: String) -> int:
	return get_current_stock_amount(item_id) + get_pending_amount(item_id)


func update(delta: float) -> void:
	if supplier_orders.is_empty():
		return

	var delivered_orders: Array = []

	for i in range(supplier_orders.size()):
		var order_data: Dictionary = supplier_orders[i]

		var time_left: float = float(order_data.get("time_left", 0.0))
		time_left -= delta
		order_data["time_left"] = time_left
		supplier_orders[i] = order_data

		if time_left <= 0.0:
			delivered_orders.append(order_data)

	for order_data in delivered_orders:
		deliver_order(order_data)
		supplier_orders.erase(order_data)

	if panel_controller.is_open():
		refresh_panel()


func deliver_order(order_data: Dictionary) -> void:
	var items = order_data.get("items", {})

	if typeof(items) != TYPE_DICTIONARY:
		return

	for item_id in items.keys():
		var amount: int = int(items.get(item_id, 0))
		var item_key: String = str(item_id)

		if amount <= 0:
			continue

		manager.inventory_system.add_stock(item_key, amount)

	print("Supplier order delivered: ", items)
	print("Raw stock after supplier delivery: ", manager.raw_stock)
	print("Staple stock after supplier delivery: ", manager.staple_stock)

	if panel_controller.is_open():
		refresh_panel()
