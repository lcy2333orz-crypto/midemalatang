class_name InventorySystem
extends RefCounted

var manager = null


func bind(game_manager: Node) -> void:
	manager = game_manager


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	if manager == null or not is_instance_valid(manager):
		warnings.append("InventorySystem is not bound to a valid GameManager.")
		return warnings

	if typeof(manager.raw_stock) != TYPE_DICTIONARY:
		warnings.append("InventorySystem: raw_stock is not a Dictionary.")
	else:
		_append_stock_warnings(warnings, "raw_stock", manager.raw_stock)

	if typeof(manager.cooked_stock) != TYPE_DICTIONARY:
		warnings.append("InventorySystem: cooked_stock is not a Dictionary.")
	else:
		_append_stock_warnings(warnings, "cooked_stock", manager.cooked_stock)

	if typeof(manager.staple_stock) != TYPE_DICTIONARY:
		warnings.append("InventorySystem: staple_stock is not a Dictionary.")
	else:
		_append_stock_warnings(warnings, "staple_stock", manager.staple_stock)

	if _is_stock_out_of_sync(RunSetupData.current_raw_stock, manager.raw_stock):
		warnings.append("InventorySystem: raw_stock and RunSetupData.current_raw_stock are out of sync.")

	if _is_stock_out_of_sync(RunSetupData.current_cooked_stock, manager.cooked_stock):
		warnings.append("InventorySystem: cooked_stock and RunSetupData.current_cooked_stock are out of sync.")

	if _is_stock_out_of_sync(RunSetupData.current_staple_stock, manager.staple_stock):
		warnings.append("InventorySystem: staple_stock and RunSetupData.current_staple_stock are out of sync.")

	return warnings


func initialize_round_stocks(planned_raw_stock: Dictionary, planned_cooked_stock: Dictionary, planned_staple_stock: Dictionary) -> void:
	if RunSetupData.current_raw_stock.is_empty():
		RunSetupData.current_raw_stock = planned_raw_stock.duplicate(true)

	if RunSetupData.current_cooked_stock.is_empty():
		RunSetupData.current_cooked_stock = planned_cooked_stock.duplicate(true)

	if RunSetupData.current_staple_stock.is_empty():
		RunSetupData.current_staple_stock = planned_staple_stock.duplicate(true)

	manager.raw_stock = RunSetupData.current_raw_stock.duplicate(true)
	manager.cooked_stock = RunSetupData.current_cooked_stock.duplicate(true)
	manager.staple_stock = RunSetupData.current_staple_stock.duplicate(true)


func get_stock_total(stock: Dictionary) -> int:
	return StockUtils.get_total(stock)


func can_fulfill_from_cooked(ingredients: Dictionary) -> bool:
	for ingredient_name in ingredients.keys():
		var amount: int = int(ingredients[ingredient_name])

		if not manager.cooked_stock.has(ingredient_name):
			return false

		if int(manager.cooked_stock[ingredient_name]) < amount:
			return false

	return true


func can_fulfill_from_combined_stock(ingredients: Dictionary) -> bool:
	for ingredient_name in ingredients.keys():
		var amount: int = int(ingredients[ingredient_name])

		var cooked_amount: int = max(int(manager.cooked_stock.get(ingredient_name, 0)), 0)
		var raw_amount: int = max(int(manager.raw_stock.get(ingredient_name, 0)), 0)

		if cooked_amount + raw_amount < amount:
			return false

	return true


func get_order_fulfillment_status(ingredients: Dictionary) -> String:
	if can_fulfill_from_cooked(ingredients):
		return "instant"

	if can_fulfill_from_combined_stock(ingredients):
		return "waitable"

	return "unfulfillable"


func deduct_cooked_stock(ingredients: Dictionary) -> void:
	print("Deducting cooked stock...")
	print("Before cooked stock: ", manager.cooked_stock)

	for ingredient_name in ingredients.keys():
		var amount: int = int(ingredients[ingredient_name])
		if not manager.cooked_stock.has(ingredient_name):
			manager.cooked_stock[ingredient_name] = 0
		manager.cooked_stock[ingredient_name] = max(int(manager.cooked_stock[ingredient_name]) - amount, 0)

	_sync_cooked_stock()

	print("After cooked stock: ", manager.cooked_stock)


func consume_raw_stock_for_order(ingredients: Dictionary) -> void:
	print("Consuming raw stock...")
	print("Before raw stock: ", manager.raw_stock)

	for ingredient_name in ingredients.keys():
		var amount: int = int(ingredients[ingredient_name])

		if not manager.raw_stock.has(ingredient_name):
			manager.raw_stock[ingredient_name] = 0

		manager.raw_stock[ingredient_name] = max(int(manager.raw_stock[ingredient_name]) - amount, 0)

	_sync_raw_stock()

	print("After raw stock: ", manager.raw_stock)


func add_cooked_stock_for_order(ingredients: Dictionary) -> void:
	print("Adding cooked stock...")
	print("Before cooked stock: ", manager.cooked_stock)

	for ingredient_name in ingredients.keys():
		var amount: int = int(ingredients[ingredient_name])

		if not manager.cooked_stock.has(ingredient_name):
			manager.cooked_stock[ingredient_name] = 0

		manager.cooked_stock[ingredient_name] = int(manager.cooked_stock[ingredient_name]) + amount

	_sync_cooked_stock()

	print("After cooked stock: ", manager.cooked_stock)


func get_cooked_stock_text() -> String:
	return _get_stock_text(manager.cooked_stock)


func get_raw_stock_text() -> String:
	return _get_stock_text(manager.raw_stock)


func get_staple_stock_text() -> String:
	var parts: Array[String] = []

	for item_id in RunSetupData.get_staple_item_ids():
		parts.append("%s x%d" % [
			manager.get_ingredient_display_name(item_id),
			int(manager.staple_stock.get(item_id, 0))
		])

	if parts.is_empty():
		return "æ— "

	return ", ".join(parts)


func get_order_shortage(ingredients: Dictionary) -> Dictionary:
	var shortage: Dictionary = {}

	for ingredient_name in ingredients.keys():
		var amount: int = int(ingredients[ingredient_name])

		var cooked_amount: int = max(int(manager.cooked_stock.get(ingredient_name, 0)), 0)
		var raw_amount: int = max(int(manager.raw_stock.get(ingredient_name, 0)), 0)

		var total_amount: int = cooked_amount + raw_amount
		var missing_amount: int = max(amount - total_amount, 0)

		if missing_amount > 0:
			shortage[ingredient_name] = missing_amount

	return shortage


func add_stock(item_id: String, amount: int) -> void:
	if amount <= 0:
		return

	if RunSetupData.is_staple_item(item_id):
		if not manager.staple_stock.has(item_id):
			manager.staple_stock[item_id] = 0

		manager.staple_stock[item_id] = int(manager.staple_stock.get(item_id, 0)) + amount
		_sync_staple_stock()
	else:
		if not manager.raw_stock.has(item_id):
			manager.raw_stock[item_id] = 0

		manager.raw_stock[item_id] = int(manager.raw_stock.get(item_id, 0)) + amount
		_sync_raw_stock()


func _get_stock_text(stock: Dictionary) -> String:
	var lines: Array[String] = []

	for key in stock.keys():
		var amount = int(stock.get(key, 0))
		if amount > 0:
			lines.append("%s x%d" % [TextDB.get_item_name(key), amount])

	if lines.is_empty():
		return TextDB.get_text("UI_ITEM_NONE")

	return ", ".join(lines)


func _append_stock_warnings(warnings: Array[String], stock_name: String, stock: Dictionary) -> void:
	for item_id in stock.keys():
		var amount = stock.get(item_id, 0)

		if typeof(amount) != TYPE_INT:
			warnings.append("InventorySystem: %s[%s] is not an int." % [stock_name, str(item_id)])
			continue

		if int(amount) < 0:
			warnings.append("InventorySystem: %s[%s] is negative." % [stock_name, str(item_id)])


func _is_stock_out_of_sync(saved_stock, runtime_stock) -> bool:
	if typeof(saved_stock) != TYPE_DICTIONARY:
		return false

	if typeof(runtime_stock) != TYPE_DICTIONARY:
		return false

	return saved_stock != runtime_stock


func _sync_raw_stock() -> void:
	RunSetupData.current_raw_stock = manager.raw_stock.duplicate(true)


func _sync_cooked_stock() -> void:
	RunSetupData.current_cooked_stock = manager.cooked_stock.duplicate(true)


func _sync_staple_stock() -> void:
	RunSetupData.current_staple_stock = manager.staple_stock.duplicate(true)
