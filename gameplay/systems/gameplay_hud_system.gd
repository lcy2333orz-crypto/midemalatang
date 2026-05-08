class_name GameplayHudSystem
extends RefCounted

const CustomerOrderState = preload("res://gameplay/models/customer_order_state.gd")

var manager = null


func bind(game_manager: Node) -> void:
	manager = game_manager


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	if manager == null or not is_instance_valid(manager):
		warnings.append("GameplayHudSystem is not bound to a valid GameManager.")

	return warnings


func update() -> void:
	var game_ui = manager.get_tree().get_first_node_in_group("game_ui")
	if game_ui == null:
		return

	game_ui.update_business_state(
		manager.day_time_left,
		manager.is_open_for_business,
		manager.is_round_closing,
		manager.has_round_finished,
		manager.is_cleanup_phase
	)

	game_ui.hide_patience()
	_refresh_pending_order_cards(game_ui)


func reset_for_new_day() -> void:
	var game_ui = manager.get_tree().get_first_node_in_group("game_ui")
	if game_ui == null:
		return

	game_ui.update_money(manager.economy_system.money)
	game_ui.hide_order()
	game_ui.hide_stock()
	game_ui.hide_patience()
	game_ui.hide_pending_orders()
	game_ui.update_business_state(
		manager.day_time_left,
		manager.is_open_for_business,
		manager.is_round_closing,
		manager.has_round_finished,
		manager.is_cleanup_phase
	)


func refresh_money_and_reputation_ui() -> void:
	var game_ui = manager.get_tree().get_first_node_in_group("game_ui")
	if game_ui:
		game_ui.update_money(manager.economy_system.money)


func show_storage_stock_only() -> void:
	var game_ui = manager.get_tree().get_first_node_in_group("game_ui")

	if game_ui == null:
		print("Cannot show storage stock. No game_ui found.")
		return

	var cooked_text: String = manager.inventory_system.get_cooked_stock_text()
	var raw_and_staple_text: String = "%s
%s" % [
		manager.inventory_system.get_raw_stock_text(),
		TextDB.get_text("UI_STAPLE_STOCK_LINE") % manager.inventory_system.get_staple_stock_text()
	]

	game_ui.show_stock(cooked_text, raw_and_staple_text)

	print("Show storage stock only.")
	print("Cooked stock text: ", cooked_text)
	print("Raw / staple stock text: ", raw_and_staple_text)


func hide_order_and_pending() -> void:
	var game_ui = manager.get_tree().get_first_node_in_group("game_ui")
	if game_ui:
		game_ui.hide_order()
		game_ui.hide_patience()
		game_ui.hide_pending_orders()


func _refresh_pending_order_cards(game_ui: Node) -> void:
	var order_cards: Array = []

	for customer in manager.pending_order_system.get_all():
		if customer != null and is_instance_valid(customer):
			if not CustomerOrderState.is_served(customer):
				order_cards.append(manager.order_system.get_pending_order_card_data(customer))

	if order_cards.is_empty():
		game_ui.hide_pending_orders()
	else:
		game_ui.show_pending_orders(order_cards)
