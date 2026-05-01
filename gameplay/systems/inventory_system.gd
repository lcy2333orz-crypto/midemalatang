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

	if typeof(manager.cooked_stock) != TYPE_DICTIONARY:
		warnings.append("InventorySystem: cooked_stock is not a Dictionary.")

	if typeof(manager.staple_stock) != TYPE_DICTIONARY:
		warnings.append("InventorySystem: staple_stock is not a Dictionary.")

	return warnings


func get_cooked_stock_text() -> String:
	return manager.get_cooked_stock_text()


func get_raw_stock_text() -> String:
	return manager.get_raw_stock_text()


func get_staple_stock_text() -> String:
	return manager.get_staple_stock_text()


# TODO: Move stock initialization, shortage calculations, stock text formatting,
# and stock deduction/addition methods out of GameManager.
