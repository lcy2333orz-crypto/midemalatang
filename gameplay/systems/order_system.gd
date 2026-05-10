class_name OrderSystem
extends RefCounted

const CustomerOrderState = preload("res://gameplay/models/customer_order_state.gd")

var manager = null


func bind(game_manager: Node) -> void:
	manager = game_manager


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	if manager == null or not is_instance_valid(manager):
		warnings.append("OrderSystem is not bound to a valid GameManager.")
		return warnings

	if manager.pending_order_system == null:
		warnings.append("OrderSystem: PendingOrderSystem is missing.")
		return warnings

	for customer in manager.pending_order_system.get_all():
		if customer == null or not is_instance_valid(customer):
			warnings.append("OrderSystem: pending_customers contains an invalid customer.")
			continue

		if CustomerOrderState.is_served(customer):
			warnings.append("OrderSystem: served customer is still in pending_customers.")

		if CustomerOrderState.needs_emergency_purchase(customer) and customer.has_method("can_be_delivered") and customer.can_be_delivered():
			warnings.append("OrderSystem: customer is both marked for emergency purchase and deliverable.")

		_append_pending_customer_business_warnings(warnings, customer)

	return warnings


func _append_pending_customer_business_warnings(warnings: Array[String], customer: Node) -> void:
	if not CustomerOrderState.is_checked_out(customer):
		warnings.append("OrderSystem: pending customer has not completed checkout.")

	if not bool(customer.get("is_waiting_after_checkout")) and not CustomerOrderState.is_served(customer):
		warnings.append("OrderSystem: pending customer is not marked as waiting after checkout.")

	if manager.queued_customers.has(customer):
		warnings.append("OrderSystem: customer is both queued and pending.")

	var remaining_main_food: String = get_pending_order_remaining_main_food_text(customer)
	var remaining_ingredients: Dictionary = get_pending_order_remaining_ingredients(customer)
	var fully_submitted: bool = remaining_main_food == "" and remaining_ingredients.is_empty()
	var can_deliver: bool = false

	if customer.has_method("can_be_delivered"):
		can_deliver = bool(customer.can_be_delivered())

	if can_deliver and CustomerOrderState.needs_emergency_purchase(customer):
		warnings.append("OrderSystem: deliverable customer still needs emergency purchase.")

	if fully_submitted and not can_deliver:
		warnings.append("OrderSystem: pending customer has no remaining items but is not deliverable.")

	if can_deliver and not fully_submitted:
		warnings.append("OrderSystem: deliverable customer still has remaining order text.")

	var reserved_cooked: Dictionary = CustomerOrderState.get_reserved_cooked_ingredients(customer)
	_append_positive_amount_dictionary_warnings(warnings, reserved_cooked, "reserved_cooked_ingredients")

	var ingredients_to_cook: Dictionary = CustomerOrderState.get_ingredients_to_cook(customer)
	_append_positive_amount_dictionary_warnings(warnings, ingredients_to_cook, "ingredients_to_cook")

	if CustomerOrderState.is_main_food_ready(customer) and CustomerOrderState.needs_main_food(customer):
		warnings.append("OrderSystem: main food is ready but needs_main_food is still true.")

	if CustomerOrderState.is_ingredients_ready(customer) and CustomerOrderState.needs_ingredients(customer):
		warnings.append("OrderSystem: ingredients are ready but needs_ingredients is still true.")


func _append_positive_amount_dictionary_warnings(warnings: Array[String], source: Dictionary, field_name: String) -> void:
	for item_id in source.keys():
		var amount = source.get(item_id, 0)
		if typeof(amount) != TYPE_INT:
			warnings.append("OrderSystem: %s[%s] is not an int." % [field_name, str(item_id)])
			continue
		if int(amount) < 0:
			warnings.append("OrderSystem: %s[%s] is negative." % [field_name, str(item_id)])


func begin_checkout(customer: Node) -> bool:
	if customer == null or not is_instance_valid(customer):
		return false

	if CustomerOrderState.is_checked_out(customer):
		print("This customer has already checked out.")
		return false

	CustomerOrderState.set_order_revealed(customer, true)
	if customer.has_method("mark_checkout_started"):
		customer.mark_checkout_started()

	var game_ui = manager.get_tree().get_first_node_in_group("game_ui")
	if game_ui:
		game_ui.show_order(
			customer.get_order_name(),
			customer.get_main_food(),
			customer.get_ingredients_text()
		)

	print("Customer order revealed: ", customer.get_order_name())
	print("Main food: ", customer.get_main_food())
	print("Ingredients: ", customer.get_ingredients_text())
	manager.gameplay_hud_system.notify_order_revealed(customer)
	return true


func evaluate_order_before_checkout(customer: Node) -> Dictionary:
	var result: Dictionary = {
		"status": "invalid",
		"needs_waiting": false,
		"needs_main_food_cooking": false,
		"needs_ingredient_cooking": false,
		"needs_emergency_purchase": false,
		"fulfillment_status": "invalid",
		"shortage": {}
	}

	if customer == null or not is_instance_valid(customer):
		return result

	var ingredients: Dictionary = customer.get_ingredients()
	var fulfillment_status: String = manager.inventory_system.get_order_fulfillment_status(ingredients)
	var has_main_food: bool = customer.get_main_food_id() != "none"

	var needs_main_food_cooking: bool = has_main_food
	var needs_ingredient_cooking: bool = fulfillment_status != "instant"
	var needs_emergency_purchase: bool = fulfillment_status == "unfulfillable"
	var needs_waiting: bool = needs_main_food_cooking or needs_ingredient_cooking or needs_emergency_purchase

	result["status"] = "ok"
	result["needs_waiting"] = needs_waiting
	result["needs_main_food_cooking"] = needs_main_food_cooking
	result["needs_ingredient_cooking"] = needs_ingredient_cooking
	result["needs_emergency_purchase"] = needs_emergency_purchase
	result["fulfillment_status"] = fulfillment_status
	result["shortage"] = manager.inventory_system.get_order_shortage(ingredients)

	return result


func customer_can_checkout_now(customer: Node) -> bool:
	if customer == null or not is_instance_valid(customer):
		return false
	return not CustomerOrderState.is_checked_out(customer)


func get_counter_customer_stock_preview(customer: Node) -> Dictionary:
	if customer == null or not is_instance_valid(customer):
		return {}

	return {
		"cooked_text": manager.inventory_system.get_cooked_stock_text(),
		"raw_text": manager.inventory_system.get_raw_stock_text(),
		"shortage": manager.inventory_system.get_order_shortage(customer.get_ingredients()),
		"adjusted_order": get_adjusted_order(customer.get_ingredients())
	}


func confirm_checkout(customer: Node, quoted_price: int = -1) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"price_reaction": "accept",
		"final_price": 0,
		"route": "none",
		"message": ""
	}

	if customer == null or not is_instance_valid(customer):
		result["message"] = "Invalid customer."
		return result

	if CustomerOrderState.is_checked_out(customer):
		result["message"] = "Customer already checked out."
		return result

	var evaluation: Dictionary = evaluate_order_before_checkout(customer)
	if evaluation["status"] != "ok":
		result["message"] = "Order evaluation failed."
		return result

	var true_price: int = customer.get_order_price()
	var final_price: int = true_price if quoted_price < 0 else quoted_price

	var price_reaction: String = manager.resolve_price_reaction(customer, final_price, true_price)
	result["price_reaction"] = price_reaction
	result["final_price"] = final_price

	if price_reaction != "accept":
		result["message"] = "Customer did not accept the quoted price yet."
		return result

	CustomerOrderState.mark_payment_completed(customer, final_price, true_price)

	manager.economy_system.add_money(final_price)

	var game_ui = manager.get_tree().get_first_node_in_group("game_ui")
	if game_ui:
		game_ui.hide_order()

	var route_result: String = route_after_payment(customer, evaluation)
	result["success"] = true
	result["route"] = route_result
	result["message"] = "Checkout completed."
	manager.gameplay_hud_system.notify_checkout_completed(customer)

	return result


func route_after_payment(customer: Node, evaluation: Dictionary) -> String:
	var fulfillment_status: String = str(evaluation.get("fulfillment_status", "invalid"))
	var needs_waiting: bool = bool(evaluation.get("needs_waiting", false))
	var needs_main_food_cooking: bool = bool(evaluation.get("needs_main_food_cooking", false))
	var needs_ingredient_cooking: bool = bool(evaluation.get("needs_ingredient_cooking", false))
	var needs_emergency_purchase: bool = bool(evaluation.get("needs_emergency_purchase", false))

	if needs_emergency_purchase:
		_route_waiting_customer(customer, needs_main_food_cooking, true, true)
		print("Customer paid, but order currently needs emergency purchase.")
		return "waiting_emergency"

	if fulfillment_status == "instant":
		prepare_stock_for_waiting_order(customer, fulfillment_status)

		if not needs_waiting:
			customer.mark_order_served()
			manager.reputation_system.record_served(customer)

			var instant_exit_point: Node = manager.get_tree().get_first_node_in_group("exit_point") as Node
			if instant_exit_point:
				customer.go_to_exit(instant_exit_point.global_position)

			manager.customer_queue_system.release_counter_customer(customer)

			print("Customer paid and took food immediately.")
			return "instant_leave"

		_route_waiting_customer(customer, needs_main_food_cooking, false, false)
		print("Customer paid and is now waiting for main food.")
		return "waiting_delivery"

	if fulfillment_status == "waitable":
		prepare_stock_for_waiting_order(customer, fulfillment_status)

		var ingredients_to_cook: Dictionary = get_customer_ingredients_to_cook(customer)
		var still_needs_ingredients: bool = not ingredients_to_cook.is_empty()

		_route_waiting_customer(customer, needs_main_food_cooking, still_needs_ingredients, false)

		if not still_needs_ingredients and customer.has_method("mark_cart_ingredients_ready"):
			customer.mark_cart_ingredients_ready()

		print("Customer paid and is now waiting for food.")
		return "waiting_delivery"

	_route_waiting_customer(customer, needs_main_food_cooking, true, true)
	print("Customer paid, but order currently needs emergency purchase.")
	return "waiting_emergency"


func _route_waiting_customer(customer: Node, needs_main_food_cooking: bool, needs_ingredient_cooking: bool, needs_emergency_purchase: bool) -> void:
	CustomerOrderState.set_needs_main_food(customer, needs_main_food_cooking)
	CustomerOrderState.set_needs_ingredients(customer, needs_ingredient_cooking)
	CustomerOrderState.set_needs_emergency_purchase(customer, needs_emergency_purchase)

	if needs_emergency_purchase:
		CustomerOrderState.set_reserved_cooked_ingredients(customer, {})
		CustomerOrderState.set_ingredients_to_cook(customer, customer.get_ingredients())
		CustomerOrderState.set_ingredients_deducted_at_checkout(customer, false)

	customer.start_waiting_for_food(needs_main_food_cooking, needs_ingredient_cooking)

	var delivery_spot: Node = manager.get_tree().get_first_node_in_group("delivery_spot") as Node
	if delivery_spot:
		customer.go_to_delivery(delivery_spot.global_position)
	else:
		print("No delivery spot found.")

	manager.pending_order_system.add(customer)

	manager.customer_queue_system.release_counter_customer(customer)


func prepare_stock_for_waiting_order(customer: Node, fulfillment_status: String) -> void:
	if customer == null or not is_instance_valid(customer):
		return

	var ingredients: Dictionary = customer.get_ingredients()
	var reserved_cooked: Dictionary = {}
	var remaining_to_cook: Dictionary = {}

	if fulfillment_status == "instant":
		manager.inventory_system.deduct_cooked_stock(ingredients)

		CustomerOrderState.set_reserved_cooked_ingredients(customer, ingredients)
		CustomerOrderState.set_ingredients_to_cook(customer, {})
		CustomerOrderState.set_ingredients_deducted_at_checkout(customer, true)

		RunSetupData.set_stock_state(manager.raw_stock, manager.cooked_stock, manager.staple_stock)
		return

	if fulfillment_status == "waitable":
		print("Preparing cart waiting order...")
		print("Before cooked stock: ", manager.cooked_stock)
		print("Before raw stock: ", manager.raw_stock)

		for ingredient_name in ingredients.keys():
			var item_key: String = str(ingredient_name)
			var needed_amount: int = int(ingredients.get(item_key, 0))

			if needed_amount <= 0:
				continue

			var available_cooked: int = int(manager.cooked_stock.get(item_key, 0))
			if available_cooked < 0:
				available_cooked = 0

			var reserve_cooked_amount: int = int(min(needed_amount, available_cooked))
			var missing_amount: int = int(max(needed_amount - reserve_cooked_amount, 0))

			if reserve_cooked_amount > 0:
				reserved_cooked[item_key] = reserve_cooked_amount
				manager.cooked_stock[item_key] = available_cooked - reserve_cooked_amount

			if missing_amount > 0:
				remaining_to_cook[item_key] = missing_amount

		CustomerOrderState.set_reserved_cooked_ingredients(customer, reserved_cooked)
		CustomerOrderState.set_ingredients_to_cook(customer, remaining_to_cook)
		CustomerOrderState.set_ingredients_deducted_at_checkout(customer, true)

		RunSetupData.set_stock_state(manager.raw_stock, manager.cooked_stock, manager.staple_stock)

		print("Reserved cooked ingredients: ", reserved_cooked)
		print("Remaining ingredients to cook in cart pot: ", remaining_to_cook)
		print("After cooked stock: ", manager.cooked_stock)
		print("Raw stock is NOT deducted at checkout in cart mode: ", manager.raw_stock)
		return

	CustomerOrderState.set_reserved_cooked_ingredients(customer, {})
	CustomerOrderState.set_ingredients_to_cook(customer, ingredients)
	CustomerOrderState.set_ingredients_deducted_at_checkout(customer, false)


func get_customer_ingredients_to_cook(customer: Node) -> Dictionary:
	return CustomerOrderState.get_ingredients_to_cook(customer)


func get_customer_main_food_stock_id(customer: Node) -> String:
	if customer == null or not is_instance_valid(customer):
		return "none"

	if not customer.has_method("get_main_food_id"):
		return "none"

	return str(customer.get_main_food_id())


func customer_has_main_food(customer: Node) -> bool:
	var main_food_id: String = get_customer_main_food_stock_id(customer)
	return main_food_id != "none" and main_food_id != ""


func reserve_main_food_stock_for_customer(customer: Node) -> bool:
	if customer == null or not is_instance_valid(customer):
		return false

	if CustomerOrderState.was_main_food_deducted_at_checkout(customer):
		return true

	if not customer_has_main_food(customer):
		CustomerOrderState.set_main_food_reservation(customer, "none", true)
		return true

	var main_food_id: String = get_customer_main_food_stock_id(customer)

	if int(manager.staple_stock.get(main_food_id, 0)) <= 0:
		print("Main food stock is not enough: ", main_food_id)
		print("Staple stock: ", manager.staple_stock)
		return false

	manager.staple_stock[main_food_id] = int(manager.staple_stock.get(main_food_id, 0)) - 1
	CustomerOrderState.set_main_food_reservation(customer, main_food_id, true)

	RunSetupData.set_stock_state(manager.raw_stock, manager.cooked_stock, manager.staple_stock)

	print("Reserved main food: ", main_food_id)
	print("Staple stock after reserving main food: ", manager.staple_stock)

	return true


func can_make_ingredient(ingredient_name: String, amount: int) -> bool:
	var cooked_amount: int = max(int(manager.cooked_stock.get(ingredient_name, 0)), 0)
	var raw_amount: int = max(int(manager.raw_stock.get(ingredient_name, 0)), 0)
	return cooked_amount + raw_amount >= amount


func get_adjusted_order(ingredients: Dictionary) -> Dictionary:
	var adjusted_order: Dictionary = {}

	for ingredient_name in ingredients.keys():
		var item_key: String = str(ingredient_name)
		var amount: int = int(ingredients.get(item_key, 0))

		if can_make_ingredient(item_key, amount):
			adjusted_order[item_key] = amount

	return adjusted_order


func handle_stock_shortage_for_customer(customer: Node) -> Dictionary:
	var result: Dictionary = {
		"has_alternative": false,
		"adjusted_order": {},
		"should_leave": false
	}

	if customer == null or not is_instance_valid(customer):
		result["should_leave"] = true
		return result

	var adjusted_order: Dictionary = get_adjusted_order(customer.get_ingredients())
	if adjusted_order.size() > 0:
		result["has_alternative"] = true
		result["adjusted_order"] = adjusted_order
	else:
		result["should_leave"] = true

	return result


func apply_adjusted_order_to_customer(customer: Node, adjusted_order: Dictionary) -> void:
	if customer == null or not is_instance_valid(customer):
		return

	customer.set_ingredients(adjusted_order)
	CustomerOrderState.set_order_revealed(customer, true)

	if customer.has_method("mark_back_to_counter_waiting"):
		customer.mark_back_to_counter_waiting()

	var game_ui = manager.get_tree().get_first_node_in_group("game_ui")
	if game_ui:
		game_ui.show_order(
			customer.get_order_name(),
			customer.get_main_food(),
			customer.get_ingredients_text()
		)

	print("Customer accepts adjusted order: ", customer.get_ingredients_text())


func reject_customer_before_checkout(customer: Node) -> void:
	if customer == null or not is_instance_valid(customer):
		return

	manager.reputation_system.record_failed(customer, "rejected before checkout")

	var exit_point = manager.get_tree().get_first_node_in_group("exit_point")

	if exit_point:
		customer.go_to_exit(exit_point.global_position)

	manager.customer_queue_system.release_counter_customer(customer)

	print("Customer leaves before checkout.")


func is_pending_customer_fully_submitted(customer: Node) -> bool:
	if customer == null or not is_instance_valid(customer):
		return false

	if CustomerOrderState.is_served(customer):
		return false

	var remaining_main_food_text: String = get_pending_order_remaining_main_food_text(customer)
	var remaining_ingredients: Dictionary = get_pending_order_remaining_ingredients(customer)

	return remaining_main_food_text == "" and remaining_ingredients.is_empty()


func interact_with_delivery_point() -> void:
	var changed_anything: bool = false
	var completed_customer: Node = null

	if manager.cooking_system.held_staple_food_id != "":
		var staple_customer: Node = manager.cooking_system.hand_over_held_staple_to_waiting_customer()

		if staple_customer == null:
			print(TextDB.get_text("LOG_ORDER_NO_CUSTOMER_WAITING_STAPLE"))
			return

		changed_anything = true

		if staple_customer.can_be_delivered() or is_pending_customer_fully_submitted(staple_customer):
			completed_customer = staple_customer

		if completed_customer != null:
			complete_delivery(completed_customer)
			return

		print(TextDB.get_text("LOG_ORDER_STAPLE_SUBMITTED_PARTIAL"))
		_refresh_cart_pot_panel_if_open()
		return

	for customer in manager.pending_order_system.get_all():
		if customer == null or not is_instance_valid(customer):
			continue

		if CustomerOrderState.is_served(customer):
			continue

		if customer.can_be_delivered() or is_pending_customer_fully_submitted(customer):
			completed_customer = customer
			break

		if manager.cooking_system.try_fulfill_cart_ingredients_for_customer(customer):
			changed_anything = true

			if customer.can_be_delivered() or is_pending_customer_fully_submitted(customer):
				completed_customer = customer

			break

	if completed_customer != null:
		complete_delivery(completed_customer)
		return

	if changed_anything:
		print(TextDB.get_text("LOG_ORDER_INGREDIENTS_SUBMITTED_PARTIAL"))
		_refresh_cart_pot_panel_if_open()
		return

	print("No deliverable customer.")


func complete_delivery(customer: Node) -> bool:
	if customer == null or not is_instance_valid(customer):
		print("Cannot deliver: invalid customer.")
		return false

	var can_complete: bool = customer.can_be_delivered() or is_pending_customer_fully_submitted(customer)

	if not can_complete:
		print("Cannot deliver: customer order is not ready.")
		return false

	CustomerOrderState.clear_waiting_flags(customer)

	customer.mark_order_served()
	manager.reputation_system.record_served(customer)
	manager.customer_queue_system.remove_customer_from_pending(customer)

	var exit_point = manager.get_tree().get_first_node_in_group("exit_point")
	if exit_point:
		customer.go_to_exit(exit_point.global_position)

	print("Delivered order to customer.")
	_refresh_cart_pot_panel_if_open()
	manager.gameplay_hud_system.notify_order_delivered(customer)
	manager.customer_queue_system.on_tutorial_order_delivered()

	return true


func get_first_deliverable_pending_customer() -> Node:
	return manager.pending_order_system.get_first_deliverable()


func get_pending_order_display_text(customer: Node) -> String:
	var base_text: String = str(customer.get_pending_order_summary())

	if manager.order_panel_upgrade_level <= 0:
		return base_text

	var status_id: String = get_pending_order_status_id(customer)
	var status_text: String = TextDB.get_status_name(status_id)

	if manager.order_panel_upgrade_level == 1:
		return TextDB.get_text("UI_PENDING_ORDER_STATUS") % [status_text, base_text]

	if manager.order_panel_upgrade_level == 2:
		if status_id == "cooking":
			var cooker_slot_index: int = manager.cooking_system.get_customer_cooker_slot_index(customer)
			if cooker_slot_index != -1:
				return TextDB.get_text("UI_PENDING_ORDER_STATUS_WITH_POT") % [status_text, cooker_slot_index + 1, base_text]
		return TextDB.get_text("UI_PENDING_ORDER_STATUS") % [status_text, base_text]

	var extra_target_text: String = get_pending_order_delivery_target_text(customer)

	if status_id == "cooking":
		var cooker_slot_index_2: int = manager.cooking_system.get_customer_cooker_slot_index(customer)
		if cooker_slot_index_2 != -1:
			if extra_target_text != "":
				return TextDB.get_text("UI_PENDING_ORDER_STATUS_WITH_POT_TARGET") % [status_text, cooker_slot_index_2 + 1, extra_target_text, base_text]
			return TextDB.get_text("UI_PENDING_ORDER_STATUS_WITH_POT") % [status_text, cooker_slot_index_2 + 1, base_text]

	if extra_target_text != "":
		return TextDB.get_text("UI_PENDING_ORDER_STATUS_WITH_TARGET") % [status_text, extra_target_text, base_text]

	return TextDB.get_text("UI_PENDING_ORDER_STATUS") % [status_text, base_text]


func get_pending_order_remaining_main_food_text(customer: Node) -> String:
	if customer == null or not is_instance_valid(customer):
		return ""

	if not customer_has_main_food(customer):
		return ""

	if not CustomerOrderState.needs_main_food(customer):
		return ""

	if CustomerOrderState.is_main_food_ready(customer):
		return ""

	return str(customer.get_main_food())


func get_pending_order_remaining_ingredients(customer: Node) -> Dictionary:
	if customer == null or not is_instance_valid(customer):
		return {}

	if CustomerOrderState.is_ingredients_ready(customer):
		return {}

	var ingredients_to_cook: Dictionary = CustomerOrderState.get_ingredients_to_cook(customer)
	if not ingredients_to_cook.is_empty():
		return _clean_positive_amounts(ingredients_to_cook)

	if not CustomerOrderState.needs_ingredients(customer):
		return {}

	if customer.has_method("get_ingredients"):
		var ingredients = customer.get_ingredients()
		if typeof(ingredients) == TYPE_DICTIONARY:
			return _clean_positive_amounts(ingredients)

	return {}


func get_pending_order_remaining_ingredients_text(customer: Node) -> String:
	var remaining_ingredients: Dictionary = get_pending_order_remaining_ingredients(customer)

	if remaining_ingredients.is_empty():
		return ""

	return get_items_text(remaining_ingredients)


func get_items_text(items: Dictionary) -> String:
	var parts: Array[String] = []

	for item_id in items.keys():
		var amount: int = int(items.get(item_id, 0))

		if amount <= 0:
			continue

		parts.append("%s x%d" % [
			TextDB.get_item_name(str(item_id)),
			amount
		])

	if parts.is_empty():
		return TextDB.get_text("UI_ITEM_NONE")

	return TextDB.get_text("UI_LIST_JOIN_COMMA").join(parts)


func get_pending_order_card_status_text(customer: Node) -> String:
	if customer == null or not is_instance_valid(customer):
		return ""

	if CustomerOrderState.is_served(customer):
		return TextDB.get_text("UI_PENDING_CARD_DONE")

	if customer.can_be_delivered() or is_pending_customer_fully_submitted(customer):
		return TextDB.get_text("UI_PENDING_CARD_DELIVERABLE")

	if CustomerOrderState.needs_emergency_purchase(customer):
		return TextDB.get_text("UI_PENDING_CARD_SHORTAGE")

	var remaining_main_food: String = get_pending_order_remaining_main_food_text(customer)
	var remaining_ingredients: Dictionary = get_pending_order_remaining_ingredients(customer)

	if remaining_main_food != "" and not remaining_ingredients.is_empty():
		return TextDB.get_text("UI_PENDING_CARD_WAIT_MAIN_AND_INGREDIENTS")

	if remaining_main_food != "":
		return TextDB.get_text("UI_PENDING_CARD_WAIT_MAIN")

	if not remaining_ingredients.is_empty():
		return TextDB.get_text("UI_PENDING_CARD_WAIT_INGREDIENTS")

	return TextDB.get_text("UI_PENDING_CARD_WAIT_CONFIRM")

func get_pending_order_card_data(customer: Node) -> Dictionary:
	var patience_text: String = "%d/%d" % [
		int(ceil(customer.get_display_patience_current())),
		int(customer.get_display_patience_max())
	]

	var status_text: String = get_pending_order_card_status_text(customer)
	var extra_text: String = ""

	if manager.order_panel_upgrade_level >= 1:
		var status_id: String = get_pending_order_status_id(customer)
		var upgrade_status_text: String = TextDB.get_status_name(status_id)

		if upgrade_status_text != "":
			status_text = upgrade_status_text

	return {
		"status_text": status_text,
		"main_food_text": get_pending_order_remaining_main_food_text(customer),
		"ingredients_text": get_pending_order_remaining_ingredients_text(customer),
		"patience_text": patience_text,
		"extra_text": extra_text
	}


func get_pending_order_status_id(customer: Node) -> String:
	if CustomerOrderState.needs_emergency_purchase(customer):
		return "waiting_restock"

	if customer.can_be_delivered():
		return "ready_delivery"

	if manager.cooking_system.is_customer_in_any_cooker(customer):
		return "cooking"

	return "waiting_cook"


func get_pending_order_delivery_target_text(_customer: Node) -> String:
	return ""


func _clean_positive_amounts(source: Dictionary) -> Dictionary:
	var cleaned: Dictionary = {}

	for item_id in source.keys():
		var item_key: String = str(item_id)
		var amount: int = int(source.get(item_key, 0))
		if amount > 0:
			cleaned[item_key] = amount

	return cleaned


func _refresh_cart_pot_panel_if_open() -> void:
	if manager.cooking_system.panel_controller.is_open():
		manager.cooking_system.refresh_cart_pot_panel()
