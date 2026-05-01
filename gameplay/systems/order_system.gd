class_name OrderSystem
extends RefCounted

var manager = null


func bind(game_manager: Node) -> void:
	manager = game_manager


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	if manager == null or not is_instance_valid(manager):
		warnings.append("OrderSystem is not bound to a valid GameManager.")
		return warnings

	if typeof(manager.pending_customers) != TYPE_ARRAY:
		warnings.append("OrderSystem: pending_customers is not an Array.")

	return warnings


func begin_checkout(customer: Node) -> bool:
	return manager.begin_checkout_for_customer(customer)


func confirm_checkout(customer: Node, quoted_price: int = -1) -> Dictionary:
	return manager.confirm_checkout_and_create_order(customer, quoted_price)


func interact_with_delivery_point() -> void:
	manager.interact_with_delivery_point()


func get_pending_order_card_data(customer: Node) -> Dictionary:
	return manager.get_pending_order_card_data(customer)


# TODO: Move checkout, order routing, pending-card data, and order status text
# out of GameManager once inventory/cooking boundaries are stable.
