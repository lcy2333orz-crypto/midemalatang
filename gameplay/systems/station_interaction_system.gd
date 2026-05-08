class_name StationInteractionSystem
extends RefCounted

var manager = null


func bind(game_manager: Node) -> void:
	manager = game_manager


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	if manager == null or not is_instance_valid(manager):
		warnings.append("StationInteractionSystem is not bound to a valid GameManager.")

	return warnings


func get_interaction_prompt(station_name: String) -> String:
	match station_name:
		"Counter":
			return _get_counter_prompt()
		"Cooker":
			return TextDB.get_text("UI_PROMPT_COOKER")
		"DeliveryPoint":
			return _get_delivery_prompt()
		"StorageArea":
			return TextDB.get_text("UI_PROMPT_STORAGE")
		"EmergencyShop":
			return TextDB.get_text("UI_PROMPT_EMERGENCY_SHOP")
		"GiftBox":
			return TextDB.get_text("UI_PROMPT_GIFT_BOX")
		"GlassNoodleBasket":
			return _get_staple_basket_prompt("glass_noodle")
		"NoodleBasket":
			return _get_staple_basket_prompt("noodle")
		"StapleLadle1":
			return _get_ladle_prompt(0, TextDB.get_text("UI_LADLE_1"))
		"StapleLadle2":
			return _get_ladle_prompt(1, TextDB.get_text("UI_LADLE_2"))
		_:
			return TextDB.get_text("UI_PROMPT_INTERACT")


func interact(station_name: String) -> void:
	print("Interact with ", station_name)

	match station_name:
		"Counter":
			_interact_counter()
		"Cooker":
			manager.cooking_system.open_cart_pot_panel()
		"DeliveryPoint":
			manager.order_system.interact_with_delivery_point()
		"StorageArea":
			manager.supplier_system.open_panel()
		"EmergencyShop":
			_interact_emergency_shop()
		"GiftBox":
			manager.day_event_system.interact_with_gift_box()
		"GlassNoodleBasket":
			manager.cooking_system.interact_with_staple_basket("glass_noodle")
		"NoodleBasket":
			manager.cooking_system.interact_with_staple_basket("noodle")
		"StapleLadle1":
			manager.cooking_system.interact_with_staple_ladle(0)
		"StapleLadle2":
			manager.cooking_system.interact_with_staple_ladle(1)
		_:
			print("Unknown station interaction.")


func toggle_business(station_name: String) -> void:
	if station_name != "Counter":
		print("This station cannot toggle business.")
		return

	if manager.is_round_closing or manager.has_round_finished:
		print("Round is closing or already finished. Business cannot be reopened.")
		return

	if manager.is_open_for_business:
		manager.business_day_system.close_business()
		print("Counter toggled business: close")
	else:
		manager.open_business()
		print("Counter toggled business: open")


func on_player_entered_station(station_name: String) -> void:
	if station_name == "StorageArea":
		manager.gameplay_hud_system.show_storage_stock_only()


func _get_counter_prompt() -> String:
	if manager.business_day_system.can_finalize_day_now():
		return TextDB.get_text("UI_PROMPT_COUNTER_SETTLEMENT")

	if not manager.is_open_for_business:
		return TextDB.get_text("UI_PROMPT_COUNTER_OPEN")

	var customer = manager.customer_queue_system.get_counter_customer()

	if customer == null:
		return TextDB.get_text("UI_PROMPT_COUNTER_WAITING")

	if not bool(customer.order_revealed):
		return TextDB.get_text("UI_PROMPT_COUNTER_VIEW_ORDER")

	if not bool(customer.is_checked_out):
		return TextDB.get_text("UI_PROMPT_COUNTER_PAY")

	return TextDB.get_text("UI_PROMPT_COUNTER_PAID")


func _get_delivery_prompt() -> String:
	if str(manager.cooking_system.held_staple_food_id) != "":
		return TextDB.get_text("UI_PROMPT_DELIVERY_STAPLE")

	return TextDB.get_text("UI_PROMPT_DELIVERY")


func _get_staple_basket_prompt(main_food_id: String) -> String:
	var display_name: String = TextDB.get_item_name(main_food_id)
	var held_raw: String = str(manager.cooking_system.held_raw_staple_food_id)
	var held_cooked: String = str(manager.cooking_system.held_staple_food_id)

	if held_cooked != "":
		return TextDB.get_text("UI_PROMPT_HELD_COOKED_STAPLE")

	if held_raw == "":
		return TextDB.get_text("UI_PROMPT_TAKE_ITEM") % display_name

	if held_raw == main_food_id:
		return TextDB.get_text("UI_PROMPT_RETURN_ITEM") % display_name

	return TextDB.get_text("UI_PROMPT_HELD_OTHER_STAPLE")


func _get_ladle_prompt(slot_index: int, display_name: String) -> String:
	if slot_index < 0 or slot_index >= manager.cooking_system.staple_ladle_slots.size():
		return TextDB.get_text("UI_PROMPT_INTERACT")

	var slot: Dictionary = manager.cooking_system.staple_ladle_slots[slot_index] as Dictionary
	var state: String = str(slot.get("state", "empty"))
	var held_raw: String = str(manager.cooking_system.held_raw_staple_food_id)
	var held_cooked: String = str(manager.cooking_system.held_staple_food_id)

	if state == "empty":
		if held_raw != "":
			return TextDB.get_text("UI_PROMPT_PUT_IN_LADLE") % display_name
		return TextDB.get_text("UI_PROMPT_LADLE_EMPTY") % display_name

	if state == "cooking":
		var time_left: float = float(slot.get("time_left", 0.0))
		return TextDB.get_text("UI_PROMPT_LADLE_COOKING") % [display_name, time_left]

	if state == "ready":
		if held_cooked == "":
			return TextDB.get_text("UI_PROMPT_TAKE_FROM_LADLE") % display_name
		return TextDB.get_text("UI_PROMPT_HAND_HAS_COOKED_STAPLE")

	return TextDB.get_text("UI_PROMPT_INTERACT")


func _interact_counter() -> void:
	if manager.business_day_system.can_finalize_day_now():
		manager.business_day_system.finish_day_from_cleanup()
		return

	var customer = manager.customer_queue_system.get_counter_customer()
	print("Counter customer: ", customer)

	if customer == null:
		if not manager.is_open_for_business:
			print("未开业或已收摊，当前没有柜台顾客。")
		else:
			print("No customer at counter.")
		return

	if not customer.order_revealed:
		manager.order_system.begin_checkout(customer)
		return

	if not customer.is_checked_out:
		var quoted_price: int = customer.get_order_price()
		var checkout_result: Dictionary = manager.order_system.confirm_checkout(customer, quoted_price)
		print("Checkout result: ", checkout_result)

		if bool(checkout_result["success"]):
			print("顾客付款成功，订单正式成立。")
		else:
			print("收银未完成：", checkout_result["message"])
		return

	print("Customer already checked out.")


func _interact_emergency_shop() -> void:
	var customer: Node = manager.emergency_purchase_system.get_first_customer_needing_purchase()
	if customer == null:
		print("No customer needs emergency purchase.")
		return

	if manager.emergency_purchase_system.purchase_for_waiting_shortages():
		customer.needs_emergency_purchase = false
		print("Emergency purchase completed for customer.")
