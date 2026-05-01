class_name EmergencyPurchaseSystem
extends RefCounted

const CustomerOrderState := preload("res://gameplay/models/customer_order_state.gd")

var manager = null


func bind(game_manager: Node) -> void:
	manager = game_manager


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	if manager == null or not is_instance_valid(manager):
		warnings.append("EmergencyPurchaseSystem is not bound to a valid GameManager.")
		return warnings

	if manager.pending_order_system == null:
		warnings.append("EmergencyPurchaseSystem: PendingOrderSystem is missing.")

	if manager.inventory_system == null:
		warnings.append("EmergencyPurchaseSystem: InventorySystem is missing.")

	return warnings


func get_total_shortage() -> Dictionary:
	var total_ingredient_need: Dictionary = {}
	var total_main_food_need: Dictionary = {}
	var shortage: Dictionary = {}

	for customer in manager.pending_order_system.get_all():
		if customer == null or not is_instance_valid(customer):
			continue

		if CustomerOrderState.is_served(customer):
			continue

		var remaining_ingredients: Dictionary = manager.get_pending_order_remaining_ingredients(customer)

		for item_id in remaining_ingredients.keys():
			var item_key: String = str(item_id)
			var amount: int = int(remaining_ingredients.get(item_key, 0))

			if amount <= 0:
				continue

			total_ingredient_need[item_key] = int(total_ingredient_need.get(item_key, 0)) + amount

		if manager.customer_has_main_food(customer):
			var main_food_id: String = manager.get_customer_main_food_stock_id(customer)

			if main_food_id != "" and main_food_id != "none":
				if CustomerOrderState.needs_main_food(customer) and not CustomerOrderState.is_main_food_ready(customer):
					total_main_food_need[main_food_id] = int(total_main_food_need.get(main_food_id, 0)) + 1

	for item_id in total_ingredient_need.keys():
		var item_key: String = str(item_id)
		var total_need: int = int(total_ingredient_need.get(item_key, 0))
		var cooked_amount: int = int(manager.cooked_stock.get(item_key, 0))
		var raw_amount: int = int(manager.raw_stock.get(item_key, 0))
		var available_amount: int = cooked_amount + raw_amount
		var missing_amount: int = total_need - available_amount

		if missing_amount > 0:
			shortage[item_key] = missing_amount

	for item_id in total_main_food_need.keys():
		var item_key: String = str(item_id)
		var total_need: int = int(total_main_food_need.get(item_key, 0))
		var stock_amount: int = int(manager.staple_stock.get(item_key, 0))
		var assigned_amount: int = manager.get_assigned_staple_food_count(item_key)
		var available_amount: int = stock_amount + assigned_amount
		var missing_amount: int = total_need - available_amount

		if missing_amount > 0:
			shortage[item_key] = int(shortage.get(item_key, 0)) + missing_amount

	return shortage


func refresh_customer_states() -> void:
	for customer in manager.pending_order_system.get_all():
		if customer == null or not is_instance_valid(customer):
			continue

		if CustomerOrderState.is_served(customer):
			continue

		var customer_shortage: Dictionary = get_customer_shortage(customer)

		if customer_shortage.is_empty():
			CustomerOrderState.set_needs_emergency_purchase(customer, false)
		else:
			CustomerOrderState.set_needs_emergency_purchase(customer, true)


func get_customer_shortage(customer: Node) -> Dictionary:
	var shortage: Dictionary = {}

	if customer == null or not is_instance_valid(customer):
		return shortage

	if CustomerOrderState.is_served(customer):
		return shortage

	var remaining_ingredients: Dictionary = manager.get_pending_order_remaining_ingredients(customer)

	for item_id in remaining_ingredients.keys():
		var item_key: String = str(item_id)
		var needed_amount: int = int(remaining_ingredients.get(item_key, 0))

		if needed_amount <= 0:
			continue

		var cooked_amount: int = int(manager.cooked_stock.get(item_key, 0))
		var raw_amount: int = int(manager.raw_stock.get(item_key, 0))
		var available_amount: int = cooked_amount + raw_amount
		var missing_amount: int = needed_amount - available_amount

		if missing_amount > 0:
			shortage[item_key] = missing_amount

	if manager.customer_has_main_food(customer):
		var main_food_id: String = manager.get_customer_main_food_stock_id(customer)

		if main_food_id != "" and main_food_id != "none":
			if CustomerOrderState.needs_main_food(customer) and not CustomerOrderState.is_main_food_ready(customer):
				var stock_amount: int = int(manager.staple_stock.get(main_food_id, 0))
				var assigned_amount: int = manager.get_assigned_staple_food_count(main_food_id)
				var available_amount: int = stock_amount + assigned_amount

				if available_amount <= 0:
					shortage[main_food_id] = int(shortage.get(main_food_id, 0)) + 1

	return shortage


func get_first_customer_needing_purchase() -> Node:
	var total_shortage: Dictionary = get_total_shortage()

	if total_shortage.is_empty():
		refresh_customer_states()
		return null

	for customer in manager.pending_order_system.get_all():
		if customer == null or not is_instance_valid(customer):
			continue

		if CustomerOrderState.is_served(customer):
			continue

		var customer_shortage: Dictionary = get_customer_shortage(customer)

		if not customer_shortage.is_empty():
			CustomerOrderState.set_needs_emergency_purchase(customer, true)
			return customer

	refresh_customer_states()
	return null


func get_cost(shortage: Dictionary) -> int:
	if shortage.is_empty():
		return 0

	return RunSetupData.get_neighbor_emergency_price_for_shortage(shortage)


func purchase_for_waiting_shortages() -> bool:
	var total_shortage: Dictionary = get_total_shortage()

	if total_shortage.is_empty():
		print("No shortage to purchase.")
		refresh_customer_states()
		return false

	var cost: int = get_cost(total_shortage)

	print("Emergency purchase total shortage: ", total_shortage)
	print("Emergency purchase total cost: ", cost)

	if not manager.spend_money(cost):
		print("Emergency purchase failed.")
		return false

	for item_id in total_shortage.keys():
		var item_key: String = str(item_id)
		var amount: int = int(total_shortage.get(item_key, 0))

		if amount <= 0:
			continue

		manager.inventory_system.add_stock(item_key, amount)

	print("Emergency purchase completed.")
	print("Raw stock after emergency purchase: ", manager.raw_stock)
	print("Staple stock after emergency purchase: ", manager.staple_stock)

	for pending_customer in manager.pending_order_system.get_all():
		if pending_customer == null or not is_instance_valid(pending_customer):
			continue

		if CustomerOrderState.is_served(pending_customer):
			continue

		reserve_stock_after_purchase(pending_customer)

	refresh_customer_states()

	print("Emergency purchase completed for all currently waiting shortages.")
	return true


func reserve_stock_after_purchase(customer: Node) -> bool:
	if customer == null or not is_instance_valid(customer):
		return false

	if CustomerOrderState.is_served(customer):
		return false

	var remaining_shortage: Dictionary = get_customer_shortage(customer)

	if not remaining_shortage.is_empty():
		print("Customer still has shortage after emergency purchase.")
		print("Remaining shortage: ", remaining_shortage)
		CustomerOrderState.set_needs_emergency_purchase(customer, true)
		return false

	if not CustomerOrderState.were_ingredients_deducted_at_checkout(customer):
		if customer.has_method("get_ingredients"):
			var original_ingredients: Dictionary = customer.get_ingredients()

			if not original_ingredients.is_empty():
				if not CustomerOrderState.needs_ingredients(customer):
					var fulfillment_status: String = manager.get_order_fulfillment_status(original_ingredients)

					if fulfillment_status == "unfulfillable":
						print("Still cannot fulfill ingredients after emergency purchase.")
						print("Remaining ingredient shortage: ", manager.get_order_shortage(original_ingredients))
						CustomerOrderState.set_needs_emergency_purchase(customer, true)
						return false

					manager.order_system.prepare_stock_for_waiting_order(customer, fulfillment_status)

	if manager.customer_has_main_food(customer):
		if not CustomerOrderState.is_main_food_ready(customer):
			CustomerOrderState.set_needs_main_food(customer, true)

	CustomerOrderState.set_needs_ingredients(customer, not manager.order_system.get_customer_ingredients_to_cook(customer).is_empty())
	CustomerOrderState.set_needs_emergency_purchase(customer, false)

	print("Emergency purchase stock prepared for customer.")
	print("Raw stock after emergency preparation: ", manager.raw_stock)
	print("Cooked stock after emergency preparation: ", manager.cooked_stock)
	print("Staple stock after emergency preparation: ", manager.staple_stock)

	return true
