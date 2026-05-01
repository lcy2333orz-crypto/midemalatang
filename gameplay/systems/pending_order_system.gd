class_name PendingOrderSystem
extends RefCounted

const CustomerOrderState := preload("res://gameplay/models/customer_order_state.gd")

var manager = null
var pending_customers: Array = []


func bind(game_manager: Node) -> void:
	manager = game_manager


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []
	var seen: Dictionary = {}

	for customer in pending_customers:
		if customer == null or not is_instance_valid(customer):
			warnings.append("PendingOrderSystem: pending_customers contains an invalid customer.")
			continue

		var id := customer.get_instance_id()
		if seen.has(id):
			warnings.append("PendingOrderSystem: pending_customers contains a duplicate customer.")
		seen[id] = true

		if CustomerOrderState.is_served(customer):
			warnings.append("PendingOrderSystem: served customer is still pending.")

	return warnings


func clear() -> void:
	pending_customers.clear()


func add(customer: Node) -> void:
	if customer == null or not is_instance_valid(customer):
		return

	if not pending_customers.has(customer):
		pending_customers.append(customer)


func remove(customer: Node) -> void:
	var idx := pending_customers.find(customer)
	if idx != -1:
		pending_customers.remove_at(idx)


func has(customer: Node) -> bool:
	return pending_customers.has(customer)


func get_all() -> Array:
	return pending_customers


func has_pending() -> bool:
	for customer in pending_customers:
		if customer != null and is_instance_valid(customer):
			return true
	return false


func get_first_deliverable() -> Node:
	for customer in pending_customers:
		if customer == null or not is_instance_valid(customer):
			continue

		if CustomerOrderState.is_served(customer):
			continue

		if CustomerOrderState.needs_emergency_purchase(customer):
			continue

		if customer.has_method("can_be_delivered") and customer.can_be_delivered():
			return customer

	return null


func get_first_uncooked() -> Node:
	for customer in pending_customers:
		if customer == null or not is_instance_valid(customer):
			continue

		if CustomerOrderState.needs_emergency_purchase(customer):
			continue

		if customer.has_method("can_be_delivered") and customer.can_be_delivered():
			continue

		if manager != null and is_instance_valid(manager) and manager.is_customer_in_any_cooker(customer):
			continue

		return customer

	return null
