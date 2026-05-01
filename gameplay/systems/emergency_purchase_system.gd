class_name EmergencyPurchaseSystem
extends RefCounted

var manager = null


func bind(game_manager: Node) -> void:
	manager = game_manager


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	if manager == null or not is_instance_valid(manager):
		warnings.append("EmergencyPurchaseSystem is not bound to a valid GameManager.")
		return warnings

	if typeof(manager.pending_customers) != TYPE_ARRAY:
		warnings.append("EmergencyPurchaseSystem: pending_customers is not an Array.")

	return warnings


func get_first_customer_needing_purchase() -> Node:
	return manager.get_first_customer_needing_emergency_purchase()


func purchase_for_waiting_shortages() -> bool:
	return manager.emergency_purchase_for_customer(null)


# TODO: Move emergency shortage aggregation, payment, stock application, and
# pending customer refresh out of GameManager.
