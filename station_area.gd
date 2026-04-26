extends Area2D

@export var station_name: String = ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

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
			var evaluation = game_manager.evaluate_order_before_checkout(customer)

			if evaluation["status"] != "ok":
				print("Order evaluation failed.")
				return

			if evaluation["fulfillment_status"] == "unfulfillable":
				var shortage_result = game_manager.handle_stock_shortage_for_customer(customer)

				if shortage_result["has_alternative"]:
					game_manager.apply_adjusted_order_to_customer(customer, shortage_result["adjusted_order"])
					print("库存不足，顾客改为当前可做订单。请再次按 E 收银。")
					return
				else:
					print("库存不足且没有可替代方案，顾客离开。")
					game_manager.reject_customer_before_checkout(customer)
					return

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
		game_manager.start_cooking_pending_order()
		return

	if station_name == "DeliveryPoint":
		var customer = game_manager.get_first_deliverable_pending_customer()

		if customer == null:
			print("No deliverable customer.")
			return

		game_manager.complete_delivery_for_customer(customer)
		return

	if station_name == "StorageArea":
		var game_ui = get_tree().get_first_node_in_group("game_ui")

		if game_ui:
			game_ui.show_stock(
				game_manager.get_cooked_stock_text(),
				game_manager.get_raw_stock_text()
			)

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
	if body.is_in_group("player"):
		if body.has_method("register_nearby_station"):
			body.register_nearby_station(self)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		if body.has_method("unregister_nearby_station"):
			body.unregister_nearby_station(self)
