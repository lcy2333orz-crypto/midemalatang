class_name BusinessDaySystem
extends RefCounted

const CustomerOrderState = preload("res://gameplay/models/customer_order_state.gd")

var manager = null


func bind(game_manager: Node) -> void:
	manager = game_manager


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	if manager == null or not is_instance_valid(manager):
		warnings.append("BusinessDaySystem is not bound to a valid GameManager.")
		return warnings

	if manager.spawn_timer == null:
		warnings.append("BusinessDaySystem: SpawnTimer is missing.")

	return warnings


func update_day_timer(delta: float) -> void:
	if manager.has_round_finished:
		return

	if manager.is_round_closing:
		return

	if manager.gameplay_hud_system != null and manager.gameplay_hud_system.is_tutorial_timer_paused():
		return

	manager.day_time_left = max(manager.day_time_left - delta, 0.0)

	if manager.day_time_left <= 0.0 and not manager.auto_close_triggered:
		manager.auto_close_triggered = true
		print("=== Business time is over. Auto closing. ===")
		if manager.gameplay_hud_system != null:
			manager.gameplay_hud_system.notify_auto_closed_by_timer()

		if manager.is_open_for_business:
			close_business()
		else:
			force_close_day_before_opening()


func force_close_day_before_opening() -> void:
	manager.is_open_for_business = false
	manager.is_round_closing = true
	manager.day_time_left = 0.0

	if manager.spawn_timer != null and is_instance_valid(manager.spawn_timer):
		manager.spawn_timer.stop()

	print("=== Day time is over before opening. Enter cleanup check. ===")
	try_finish_day()


func open_business() -> void:
	if manager.is_open_for_business:
		return

	if manager.is_round_closing or manager.has_round_finished:
		print("Round is closing or already finished. Cannot open business again.")
		return

	manager.has_opened_for_business_today = true
	manager.supplier_system.close_panel()

	manager.is_open_for_business = true

	print("=== Business opened ===")

	manager.customer_queue_system.start_initial_customer_wave()


func close_business() -> void:
	if not manager.is_open_for_business:
		return

	manager.is_open_for_business = false
	manager.is_round_closing = true

	if manager.spawn_timer != null and is_instance_valid(manager.spawn_timer):
		manager.spawn_timer.stop()

	print("=== Business closed ===")
	try_finish_day()


func can_spawn_customers_now() -> bool:
	return manager.is_open_for_business


func try_finish_day() -> void:
	if manager.has_round_finished:
		return

	if manager.is_cleanup_phase:
		return

	if not manager.is_round_closing:
		return

	if not can_enter_cleanup_phase():
		return

	enter_cleanup_phase()


func can_enter_cleanup_phase() -> bool:
	if manager.has_round_finished:
		return false

	if not manager.is_round_closing:
		return false

	if has_active_customers_or_orders():
		return false

	if has_busy_cooker():
		return false

	return true


func enter_cleanup_phase() -> void:
	manager.is_cleanup_phase = true
	manager.is_open_for_business = false
	manager.is_round_closing = true

	if manager.spawn_timer != null and is_instance_valid(manager.spawn_timer):
		manager.spawn_timer.stop()

	var game_ui = manager.get_tree().get_first_node_in_group("game_ui")
	if game_ui:
		game_ui.hide_order()
		game_ui.hide_patience()
		game_ui.hide_pending_orders()
		game_ui.update_business_state(
			manager.day_time_left,
			manager.is_open_for_business,
			manager.is_round_closing,
			manager.has_round_finished,
			manager.is_cleanup_phase
		)

	print("=== Enter cleanup phase ===")
	print("Press E at the counter to enter settlement.")


func can_finalize_day_now() -> bool:
	return manager.is_cleanup_phase and not manager.has_round_finished


func finish_day_from_cleanup() -> void:
	if not can_finalize_day_now():
		print("Cannot enter settlement yet.")
		return

	print("=== Cleanup complete. Enter day settlement. ===")
	manager.finish_day()


func has_active_customers_or_orders() -> bool:
	for customer in manager.queued_customers:
		if _customer_blocks_cart_cleanup(customer):
			return true

	for customer in manager.pending_order_system.get_all():
		if _customer_blocks_cart_cleanup(customer):
			return true

	if manager.characters_node != null and is_instance_valid(manager.characters_node):
		for child in manager.characters_node.get_children():
			if _customer_blocks_cart_cleanup(child):
				return true

	var customer_nodes: Array = manager.get_tree().get_nodes_in_group("customers")

	for customer in customer_nodes:
		if _customer_blocks_cart_cleanup(customer):
			return true

	return false


func has_busy_cooker() -> bool:
	return manager.cooking_system.has_busy_cooking()


func can_finish_day_now() -> bool:
	if has_busy_cooker():
		return false

	var customers: Array = manager.get_tree().get_nodes_in_group("customers")
	for customer in customers:
		if customer != null and is_instance_valid(customer):
			return false

	return true


func _customer_blocks_cart_cleanup(customer: Node) -> bool:
	if customer == null:
		return false

	if not is_instance_valid(customer):
		return false

	if not customer.is_in_group("customers"):
		return false

	if customer.has_method("blocks_cart_cleanup"):
		return bool(customer.blocks_cart_cleanup())

	if CustomerOrderState.is_served(customer):
		return false

	if CustomerOrderState.is_leaving_due_to_patience(customer):
		return false

	return true
