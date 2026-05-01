class_name CustomerOrderState
extends RefCounted


static func is_valid_customer(customer: Node) -> bool:
	return customer != null and is_instance_valid(customer)


static func is_served(customer: Node) -> bool:
	if not is_valid_customer(customer):
		return false
	if customer.has_method("is_order_served"):
		return bool(customer.is_order_served())
	return bool(customer.get("order_served"))


static func is_checked_out(customer: Node) -> bool:
	if not is_valid_customer(customer):
		return false
	if customer.has_method("is_checkout_completed"):
		return bool(customer.is_checkout_completed())
	return bool(customer.get("is_checked_out"))


static func is_leaving_due_to_patience(customer: Node) -> bool:
	if not is_valid_customer(customer):
		return false
	if customer.has_method("is_leaving_for_patience"):
		return bool(customer.is_leaving_for_patience())
	return bool(customer.get("leaving_due_to_patience"))


static func set_order_revealed(customer: Node, value: bool) -> void:
	if not is_valid_customer(customer):
		return
	if customer.has_method("set_order_revealed"):
		customer.set_order_revealed(value)
		return
	customer.set("order_revealed", value)


static func mark_payment_completed(customer: Node, quoted_price: int, true_price: int) -> void:
	if not is_valid_customer(customer):
		return

	if customer.has_method("mark_payment_completed"):
		customer.mark_payment_completed(quoted_price, true_price)
		return

	customer.set("is_checked_out", true)
	customer.set("paid_price", quoted_price)
	customer.set("true_price_at_checkout", true_price)


static func get_paid_price(customer: Node) -> int:
	if not is_valid_customer(customer):
		return 0

	if customer.has_method("get_paid_price"):
		return int(customer.get_paid_price())

	if customer.has_method("get_order_price"):
		return int(customer.get_order_price())

	return 0


static func get_queue_index(customer: Node) -> int:
	if not is_valid_customer(customer):
		return -1
	if customer.has_method("get_queue_index"):
		return int(customer.get_queue_index())
	return int(customer.get("queue_index"))


static func get_current_state_id(customer: Node) -> int:
	if not is_valid_customer(customer):
		return -1
	if customer.has_method("get_current_state_id"):
		return int(customer.get_current_state_id())
	return int(customer.get("current_state"))


static func needs_emergency_purchase(customer: Node) -> bool:
	if not is_valid_customer(customer):
		return false
	if customer.has_method("is_waiting_for_emergency_purchase"):
		return bool(customer.is_waiting_for_emergency_purchase())
	return bool(customer.get("needs_emergency_purchase"))


static func set_needs_emergency_purchase(customer: Node, value: bool) -> void:
	if not is_valid_customer(customer):
		return
	if customer.has_method("set_waiting_for_emergency_purchase"):
		customer.set_waiting_for_emergency_purchase(value)
		return
	customer.set("needs_emergency_purchase", value)


static func needs_main_food(customer: Node) -> bool:
	if not is_valid_customer(customer):
		return false
	if customer.has_method("is_waiting_for_main_food"):
		return bool(customer.is_waiting_for_main_food())
	return bool(customer.get("needs_main_food_cooking"))


static func set_needs_main_food(customer: Node, value: bool) -> void:
	if not is_valid_customer(customer):
		return
	if customer.has_method("set_waiting_for_main_food"):
		customer.set_waiting_for_main_food(value)
		return
	customer.set("needs_main_food_cooking", value)


static func needs_ingredients(customer: Node) -> bool:
	if not is_valid_customer(customer):
		return false
	if customer.has_method("is_waiting_for_ingredients"):
		return bool(customer.is_waiting_for_ingredients())
	return bool(customer.get("needs_ingredient_cooking"))


static func set_needs_ingredients(customer: Node, value: bool) -> void:
	if not is_valid_customer(customer):
		return
	if customer.has_method("set_waiting_for_ingredients"):
		customer.set_waiting_for_ingredients(value)
		return
	customer.set("needs_ingredient_cooking", value)


static func is_main_food_ready(customer: Node) -> bool:
	if not is_valid_customer(customer):
		return false
	if customer.has_method("is_cart_main_food_ready"):
		return bool(customer.is_cart_main_food_ready())
	return bool(customer.get("cart_main_food_ready"))


static func is_ingredients_ready(customer: Node) -> bool:
	if not is_valid_customer(customer):
		return false
	if customer.has_method("is_cart_ingredients_ready"):
		return bool(customer.is_cart_ingredients_ready())
	return bool(customer.get("cart_ingredients_ready"))


static func get_ingredients_to_cook(customer: Node) -> Dictionary:
	if not is_valid_customer(customer):
		return {}

	if customer.has_meta("ingredients_to_cook"):
		var value = customer.get_meta("ingredients_to_cook")
		if typeof(value) == TYPE_DICTIONARY:
			return value

	return {}


static func set_ingredients_to_cook(customer: Node, ingredients: Dictionary) -> void:
	if is_valid_customer(customer):
		customer.set_meta("ingredients_to_cook", ingredients.duplicate(true))


static func get_reserved_cooked_ingredients(customer: Node) -> Dictionary:
	if not is_valid_customer(customer):
		return {}

	if customer.has_meta("reserved_cooked_ingredients"):
		var value = customer.get_meta("reserved_cooked_ingredients")
		if typeof(value) == TYPE_DICTIONARY:
			return value

	return {}


static func set_reserved_cooked_ingredients(customer: Node, ingredients: Dictionary) -> void:
	if is_valid_customer(customer):
		customer.set_meta("reserved_cooked_ingredients", ingredients.duplicate(true))


static func were_ingredients_deducted_at_checkout(customer: Node) -> bool:
	if not is_valid_customer(customer):
		return false
	return bool(customer.get_meta("ingredients_deducted_at_checkout", false))


static func set_ingredients_deducted_at_checkout(customer: Node, value: bool) -> void:
	if is_valid_customer(customer):
		customer.set_meta("ingredients_deducted_at_checkout", value)


static func clear_ingredient_reservations(customer: Node) -> void:
	if not is_valid_customer(customer):
		return

	set_reserved_cooked_ingredients(customer, {})
	set_ingredients_to_cook(customer, {})
	set_ingredients_deducted_at_checkout(customer, false)


static func was_main_food_deducted_at_checkout(customer: Node) -> bool:
	if not is_valid_customer(customer):
		return false
	return bool(customer.get_meta("main_food_deducted_at_checkout", false))


static func set_main_food_reservation(customer: Node, main_food_id: String, deducted: bool) -> void:
	if not is_valid_customer(customer):
		return

	customer.set_meta("main_food_deducted_at_checkout", deducted)
	customer.set_meta("reserved_main_food_id", main_food_id)


static func mark_main_food_ready(customer: Node) -> void:
	if not is_valid_customer(customer):
		return

	set_needs_main_food(customer, false)
	if customer.has_method("set_cart_main_food_ready"):
		customer.set_cart_main_food_ready(true)
	else:
		customer.set("cart_main_food_ready", true)


static func mark_ingredients_ready(customer: Node) -> void:
	if not is_valid_customer(customer):
		return

	if customer.has_method("mark_cart_ingredients_ready"):
		customer.mark_cart_ingredients_ready()
		return

	if customer.has_method("set_cart_ingredients_ready"):
		customer.set_cart_ingredients_ready(true)
	else:
		customer.set("cart_ingredients_ready", true)
	set_needs_ingredients(customer, false)


static func clear_waiting_flags(customer: Node) -> void:
	if not is_valid_customer(customer):
		return

	set_needs_emergency_purchase(customer, false)
	set_needs_main_food(customer, false)
	set_needs_ingredients(customer, false)
	if customer.has_method("set_cart_main_food_ready"):
		customer.set_cart_main_food_ready(true)
	else:
		customer.set("cart_main_food_ready", true)
	if customer.has_method("set_cart_ingredients_ready"):
		customer.set_cart_ingredients_ready(true)
	else:
		customer.set("cart_ingredients_ready", true)


static func is_special_customer(customer: Node) -> bool:
	if not is_valid_customer(customer):
		return false
	if customer.has_method("has_special_customer_flag"):
		return bool(customer.has_special_customer_flag())
	return bool(customer.get("is_special_customer"))


static func has_recorded_special_result(customer: Node) -> bool:
	if not is_valid_customer(customer):
		return false
	if customer.has_method("has_special_result_recorded"):
		return bool(customer.has_special_result_recorded())
	return bool(customer.get("special_result_recorded"))


static func set_special_result_recorded(customer: Node, value: bool) -> void:
	if not is_valid_customer(customer):
		return
	if customer.has_method("set_special_result_recorded"):
		customer.set_special_result_recorded(value)
		return
	customer.set("special_result_recorded", value)


static func get_special_customer_type(customer: Node) -> String:
	if not is_valid_customer(customer):
		return ""
	if customer.has_method("get_special_customer_type"):
		return str(customer.get_special_customer_type())
	return str(customer.get("special_customer_type"))


static func get_special_customer_name(customer: Node) -> String:
	if not is_valid_customer(customer):
		return ""
	if customer.has_method("get_special_customer_name"):
		return str(customer.get_special_customer_name())
	return str(customer.get("special_customer_name"))
