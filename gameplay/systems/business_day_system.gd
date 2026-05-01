class_name BusinessDaySystem
extends RefCounted

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

	manager.day_time_left = max(manager.day_time_left - delta, 0.0)

	if manager.day_time_left <= 0.0 and not manager.auto_close_triggered:
		manager.auto_close_triggered = true
		print("=== Business time is over. Auto closing. ===")

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
	manager.close_supplier_order_panel()

	manager.is_open_for_business = true

	print("=== Business opened ===")

	manager.start_initial_customer_wave()


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

	if manager.has_active_customers_or_orders():
		return false

	if manager.has_busy_cooker():
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
