extends Area2D

@export var station_name: String = ""
@export var interaction_label: String = ""
@export var interaction_priority: int = 0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func get_interaction_priority() -> int:
	if interaction_priority != 0:
		return interaction_priority

	match station_name:
		"Counter":
			return 100
		"DeliveryPoint":
			return 95
		"StapleLadle1", "StapleLadle2":
			return 90
		"GlassNoodleBasket", "NoodleBasket":
			return 85
		"Cooker":
			return 80
		"EmergencyShop":
			return 70
		"StorageArea":
			return 65
		"GiftBox":
			return 50
		_:
			return 10


func get_interaction_prompt() -> String:
	if interaction_label.strip_edges() != "":
		return interaction_label

	var game_manager = get_tree().get_first_node_in_group("game_manager")

	match station_name:
		"Counter":
			return _get_counter_prompt(game_manager)
		"Cooker":
			return TextDB.get_text("UI_PROMPT_COOKER")
		"DeliveryPoint":
			return _get_delivery_prompt(game_manager)
		"StorageArea":
			return TextDB.get_text("UI_PROMPT_STORAGE")
		"EmergencyShop":
			return TextDB.get_text("UI_PROMPT_EMERGENCY_SHOP")
		"GiftBox":
			return TextDB.get_text("UI_PROMPT_GIFT_BOX")
		"GlassNoodleBasket":
			return _get_staple_basket_prompt(game_manager, "glass_noodle")
		"NoodleBasket":
			return _get_staple_basket_prompt(game_manager, "noodle")
		"StapleLadle1":
			return _get_ladle_prompt(game_manager, 0, TextDB.get_text("UI_LADLE_1"))
		"StapleLadle2":
			return _get_ladle_prompt(game_manager, 1, TextDB.get_text("UI_LADLE_2"))
		_:
			return TextDB.get_text("UI_PROMPT_INTERACT")

func _get_counter_prompt(game_manager: Node) -> String:
	if game_manager == null:
		return TextDB.get_text("UI_PROMPT_COUNTER")

	if game_manager.has_method("can_finalize_day_now"):
		if game_manager.can_finalize_day_now():
			return TextDB.get_text("UI_PROMPT_COUNTER_SETTLEMENT")

	if not game_manager.is_open_for_business:
		return TextDB.get_text("UI_PROMPT_COUNTER_OPEN")

	var customer = null
	if game_manager.has_method("get_counter_customer"):
		customer = game_manager.get_counter_customer()

	if customer == null:
		return TextDB.get_text("UI_PROMPT_COUNTER_WAITING")

	if not bool(customer.order_revealed):
		return TextDB.get_text("UI_PROMPT_COUNTER_VIEW_ORDER")

	if not bool(customer.is_checked_out):
		return TextDB.get_text("UI_PROMPT_COUNTER_PAY")

	return TextDB.get_text("UI_PROMPT_COUNTER_PAID")

func _get_delivery_prompt(game_manager: Node) -> String:
	if game_manager == null:
		return TextDB.get_text("UI_PROMPT_DELIVERY")

	if game_manager.cooking_system != null:
		if str(game_manager.cooking_system.held_staple_food_id) != "":
			return TextDB.get_text("UI_PROMPT_DELIVERY_STAPLE")

	return TextDB.get_text("UI_PROMPT_DELIVERY")

func _get_staple_basket_prompt(game_manager: Node, main_food_id: String) -> String:
	var display_name: String = TextDB.get_item_name(main_food_id)

	if game_manager == null or game_manager.cooking_system == null:
		return TextDB.get_text("UI_PROMPT_TAKE_ITEM") % display_name

	var held_raw: String = str(game_manager.cooking_system.held_raw_staple_food_id)
	var held_cooked: String = str(game_manager.cooking_system.held_staple_food_id)

	if held_cooked != "":
		return TextDB.get_text("UI_PROMPT_HELD_COOKED_STAPLE")

	if held_raw == "":
		return TextDB.get_text("UI_PROMPT_TAKE_ITEM") % display_name

	if held_raw == main_food_id:
		return TextDB.get_text("UI_PROMPT_RETURN_ITEM") % display_name

	return TextDB.get_text("UI_PROMPT_HELD_OTHER_STAPLE")

func _get_ladle_prompt(game_manager: Node, slot_index: int, display_name: String) -> String:
	if game_manager == null or game_manager.cooking_system == null:
		return TextDB.get_text("UI_PROMPT_INTERACT")

	if slot_index < 0 or slot_index >= game_manager.cooking_system.staple_ladle_slots.size():
		return TextDB.get_text("UI_PROMPT_INTERACT")

	var slot: Dictionary = game_manager.cooking_system.staple_ladle_slots[slot_index] as Dictionary
	var state: String = str(slot.get("state", "empty"))
	var held_raw: String = str(game_manager.cooking_system.held_raw_staple_food_id)
	var held_cooked: String = str(game_manager.cooking_system.held_staple_food_id)

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

func interact() -> void:
	print("Interact with ", station_name)

	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager == null:
		print("No game manager found.")
		return

	if station_name == "Counter":
		if game_manager.has_method("can_finalize_day_now"):
			if game_manager.can_finalize_day_now():
				game_manager.finish_day_from_cleanup()
				return

		var customer = game_manager.get_counter_customer()
		print("Counter customer: ", customer)

		if customer == null:
			if not game_manager.is_open_for_business:
				print("未开业或已收摊，当前没有柜台顾客。")
			else:
				print("No customer at counter.")
			return

		if not customer.order_revealed:
			game_manager.begin_checkout_for_customer(customer)
			return

		if not customer.is_checked_out:
			var quoted_price = customer.get_order_price()
			var checkout_result = game_manager.confirm_checkout_and_create_order(customer, quoted_price)
			print("Checkout result: ", checkout_result)

			if checkout_result["success"]:
				print("顾客付款成功，订单正式成立。")
			else:
				print("收银未完成：", checkout_result["message"])
			return

		print("Customer already checked out.")
		return

	if station_name == "Cooker":
		if game_manager.has_method("open_cart_pot_panel"):
			game_manager.open_cart_pot_panel()
			return

		if game_manager.has_method("start_cooking_pending_order"):
			game_manager.start_cooking_pending_order()
			return

		print("No cooker interaction method found.")
		return

	if station_name == "DeliveryPoint":
		if game_manager.has_method("interact_with_delivery_point"):
			game_manager.interact_with_delivery_point()
			return

		var customer = game_manager.get_first_deliverable_pending_customer()
		if customer == null:
			print("No deliverable customer.")
			return

		game_manager.complete_delivery_for_customer(customer)
		return

	if station_name == "StorageArea":
		game_manager.open_supplier_order_panel()
		return

	if station_name == "EmergencyShop":
		var customer = game_manager.get_first_customer_needing_emergency_purchase()
		if customer == null:
			print("No customer needs emergency purchase.")
			return

		if game_manager.emergency_purchase_for_customer(customer):
			customer.needs_emergency_purchase = false
			print("Emergency purchase completed for customer.")
		return

	if station_name == "GiftBox":
		if game_manager.has_method("interact_with_gift_box"):
			game_manager.interact_with_gift_box()
		else:
			print("GameManager missing interact_with_gift_box")
		return

	if station_name == "GlassNoodleBasket":
		if game_manager.has_method("interact_with_staple_basket"):
			game_manager.interact_with_staple_basket("glass_noodle")
		else:
			print("GameManager missing interact_with_staple_basket")
		return

	if station_name == "NoodleBasket":
		if game_manager.has_method("interact_with_staple_basket"):
			game_manager.interact_with_staple_basket("noodle")
		else:
			print("GameManager missing interact_with_staple_basket")
		return

	if station_name == "StapleLadle1":
		if game_manager.has_method("interact_with_staple_ladle"):
			game_manager.interact_with_staple_ladle(0)
		else:
			print("GameManager missing interact_with_staple_ladle")
		return

	if station_name == "StapleLadle2":
		if game_manager.has_method("interact_with_staple_ladle"):
			game_manager.interact_with_staple_ladle(1)
		else:
			print("GameManager missing interact_with_staple_ladle")
		return

	print("Unknown station interaction.")


func toggle_business() -> void:
	if station_name != "Counter":
		print("This station cannot toggle business.")
		return

	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager == null:
		print("No game manager found.")
		return

	if game_manager.is_round_closing or game_manager.has_round_finished:
		print("Round is closing or already finished. Business cannot be reopened.")
		return

	if game_manager.is_open_for_business:
		game_manager.close_business()
		print("Counter toggled business: close")
	else:
		game_manager.open_business()
		print("Counter toggled business: open")


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	if body.has_method("register_nearby_station"):
		body.register_nearby_station(self)

	if station_name == "StorageArea":
		var game_manager = get_tree().get_first_node_in_group("game_manager")

		if game_manager != null and game_manager.has_method("show_storage_stock_only"):
			game_manager.show_storage_stock_only()


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	if body.has_method("unregister_nearby_station"):
		body.unregister_nearby_station(self)

	if station_name == "StorageArea":
		var game_ui = get_tree().get_first_node_in_group("game_ui")

		if game_ui != null:
			game_ui.hide_stock()
