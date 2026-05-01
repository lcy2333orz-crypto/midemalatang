class_name StockUtils
extends RefCounted

static func duplicate_int_stock(stock: Dictionary) -> Dictionary:
	var result: Dictionary = {}

	for item_id in stock.keys():
		result[str(item_id)] = int(stock.get(item_id, 0))

	return result


static func get_total(stock: Dictionary) -> int:
	var total := 0

	for item_id in stock.keys():
		total += int(stock.get(item_id, 0))

	return total


static func add_amount(stock: Dictionary, item_id: String, amount: int) -> void:
	if amount <= 0:
		return

	stock[item_id] = int(stock.get(item_id, 0)) + amount


static func remove_amount(stock: Dictionary, item_id: String, amount: int) -> void:
	if amount <= 0:
		return

	stock[item_id] = max(int(stock.get(item_id, 0)) - amount, 0)
