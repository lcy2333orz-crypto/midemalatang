class_name SupplierSystem
extends RefCounted

var manager = null


func bind(game_manager: Node) -> void:
	manager = game_manager


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	if manager == null or not is_instance_valid(manager):
		warnings.append("SupplierSystem is not bound to a valid GameManager.")
		return warnings

	if typeof(manager.supplier_orders) != TYPE_ARRAY:
		warnings.append("SupplierSystem: supplier_orders is not an Array.")

	return warnings


func open_panel() -> void:
	manager.open_supplier_order_panel()


func update(delta: float) -> void:
	manager.update_supplier_orders(delta)


func close_panel() -> void:
	manager.close_supplier_order_panel()


func get_pending_amount(item_id: String) -> int:
	return manager.get_pending_supplier_order_amount(item_id)


# TODO: Move supplier order panel construction, order timers, delivery, and
# regular purchase pricing flow out of GameManager.
