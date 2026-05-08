class_name CustomerQueueSystem
extends RefCounted

const CustomerOrderState = preload("res://gameplay/models/customer_order_state.gd")

var manager = null
var spawn_policy: Dictionary = {}
var tutorial_normal_customer_spawn_count: int = 0


func bind(game_manager: Node) -> void:
	manager = game_manager


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	if manager == null or not is_instance_valid(manager):
		warnings.append("CustomerQueueSystem is not bound to a valid GameManager.")
		return warnings

	if manager.characters_node == null:
		warnings.append("CustomerQueueSystem: Characters node is missing.")

	if manager.customer_spawn == null:
		warnings.append("CustomerQueueSystem: CustomerSpawn marker is missing.")

	if manager.queue_spot_1 == null or manager.queue_spot_2 == null or manager.queue_spot_3 == null:
		warnings.append("CustomerQueueSystem: one or more queue spots are missing.")

	if manager.customer_scene == null:
		warnings.append("CustomerQueueSystem: customer_scene is not assigned.")

	return warnings


func set_spawn_policy(policy: Dictionary) -> void:
	spawn_policy = policy.duplicate(true)


func clear_day_state() -> void:
	tutorial_normal_customer_spawn_count = 0


func get_active_queue_snapshot() -> Array:
	var snapshot: Array = []

	for customer in manager.queued_customers:
		if customer == null or not is_instance_valid(customer):
			continue

		snapshot.append({
			"name": customer.name,
			"queue_index": CustomerOrderState.get_queue_index(customer),
			"state": CustomerOrderState.get_current_state_id(customer)
		})

	return snapshot


func get_queue_positions() -> Array:
	return [
		manager.queue_spot_1.global_position,
		manager.queue_spot_2.global_position,
		manager.queue_spot_3.global_position
	]


func refresh_queue_positions() -> void:
	var queue_positions = get_queue_positions()

	for i in range(manager.queued_customers.size()):
		var customer = manager.queued_customers[i]
		if customer != null and is_instance_valid(customer) and customer.is_in_queue:
			if i < queue_positions.size():
				customer.move_to_queue_position(queue_positions[i], i)


func start_initial_customer_wave() -> void:
	if not manager.business_day_system.can_spawn_customers_now():
		return

	print("start spawning customers after opening...")
	for i in range(manager.max_queue_size):
		if manager.queued_customers.size() >= manager.max_queue_size:
			break
		print("spawn attempt after opening: ", i)
		spawn_customer()


func get_modified_spawn_timer_wait_time() -> float:
	var multiplier: float = RunSetupData.get_current_day_multiplier(
		"customer_spawn_interval_multiplier",
		1.0
	)

	return max(manager.base_spawn_timer_wait_time * multiplier, 0.2)


func start_spawn_timer_if_needed() -> void:
	if not manager.business_day_system.can_spawn_customers_now():
		return

	if manager.queued_customers.size() >= manager.max_queue_size:
		return

	if manager.spawn_timer == null:
		return

	if not is_instance_valid(manager.spawn_timer):
		return

	if not manager.spawn_timer.is_inside_tree():
		return

	manager.spawn_timer.wait_time = get_modified_spawn_timer_wait_time()
	manager.spawn_timer.start()

	print("Spawn timer started. wait_time=", manager.spawn_timer.wait_time)


func spawn_customer() -> void:
	if not manager.business_day_system.can_spawn_customers_now():
		print("Current state does not allow customer spawning.")
		return

	if manager.customer_scene == null:
		print("Customer scene is missing")
		return

	if manager.queued_customers.size() >= manager.max_queue_size:
		print("Queue already full")
		return

	var customer_instance = manager.customer_scene.instantiate()
	print("spawned customer instance: ", customer_instance)

	manager.characters_node.add_child(customer_instance)
	customer_instance.global_position = manager.customer_spawn.global_position
	print("customer initial pos: ", customer_instance.global_position)

	apply_special_customer_plan_to_customer(customer_instance)
	apply_tutorial_order_to_normal_customer(customer_instance)

	manager.queued_customers.append(customer_instance)
	refresh_queue_positions()

	customer_instance.tree_exited.connect(Callable(manager, "_on_customer_exited").bind(customer_instance))


func apply_tutorial_order_to_normal_customer(customer: Node) -> void:
	if customer == null or not is_instance_valid(customer):
		return

	if not RunSetupData.is_tutorial_day():
		return

	if CustomerOrderState.is_special_customer(customer):
		return

	if not customer.has_method("apply_forced_order"):
		return

	tutorial_normal_customer_spawn_count += 1

	if tutorial_normal_customer_spawn_count == 1:
		customer.apply_forced_order("glass_noodle", {
			"spinach": 1,
			"potato_slice": 1
		})
		print("Applied tutorial forced order to normal customer 1.")
		return

	if tutorial_normal_customer_spawn_count == 2:
		customer.apply_forced_order("noodle", {
			"tofu_puff": 1
		})
		print("Applied tutorial forced order to normal customer 2.")
		return

	if customer.has_method("get_main_food_id") and str(customer.get_main_food_id()) == "noodle":
		customer.apply_forced_order("glass_noodle", customer.get_ingredients())
		print("Replaced noodle order after tutorial customer 2.")


func apply_special_customer_plan_to_customer(customer: Node) -> void:
	if customer == null or not is_instance_valid(customer):
		return

	if RunSetupData.current_day_special_spawn_plan.is_empty():
		return

	var next_plan = RunSetupData.current_day_special_spawn_plan.pop_front()

	if typeof(next_plan) != TYPE_DICTIONARY:
		return

	var special_type: String = str(next_plan.get("type", ""))
	var special_name: String = str(next_plan.get("name", ""))

	if special_type == "" or special_name == "":
		return

	if not customer.has_method("setup_special_customer"):
		return

	customer.setup_special_customer(special_type, special_name)
	print("Applied special customer plan: ", special_type, " / ", special_name)


func get_counter_customer() -> Node:
	while not manager.queued_customers.is_empty():
		var customer = manager.queued_customers[0]
		if customer != null and is_instance_valid(customer):
			return customer
		manager.queued_customers.remove_at(0)

	return null


func remove_customer_from_queue(customer: Node) -> void:
	var idx: int = manager.queued_customers.find(customer)

	if idx != -1:
		manager.queued_customers.remove_at(idx)
		refresh_queue_positions()


func remove_customer_from_pending(customer: Node) -> void:
	manager.pending_order_system.remove(customer)


func release_counter_customer(customer: Node) -> void:
	remove_customer_from_queue(customer)
	start_spawn_timer_if_needed()


func notify_customer_leaving(customer: Node) -> void:
	var paid_price: int = 0

	if customer != null and is_instance_valid(customer):
		if CustomerOrderState.is_checked_out(customer) and not CustomerOrderState.is_served(customer):
			paid_price = CustomerOrderState.get_paid_price(customer)

	if paid_price > 0:
		manager.economy_system.money = max(manager.economy_system.money - paid_price, 0)
		manager.economy_system.round_income -= paid_price
		manager.economy_system.today_income -= paid_price
		RunSetupData.set_money_state(
			manager.economy_system.money,
			manager.economy_system.round_income,
			manager.economy_system.round_gross_income,
			manager.economy_system.round_expense
		)
		manager.economy_system._sync_manager_fields()
		print("Refund applied because customer left after payment: ", paid_price)

	manager.gameplay_hud_system.refresh_money_and_reputation_ui()

	remove_customer_from_queue(customer)
	remove_customer_from_pending(customer)
	manager.cooking_system.remove_customer_from_cooker_slots(customer)

	start_spawn_timer_if_needed()


func on_customer_exited(customer: Node) -> void:
	print("customer exited: ", customer)

	remove_customer_from_queue(customer)
	remove_customer_from_pending(customer)
	manager.cooking_system.remove_customer_from_cooker_slots(customer)

	start_spawn_timer_if_needed()


func on_spawn_timer_timeout() -> void:
	if not manager.business_day_system.can_spawn_customers_now():
		return

	if manager.queued_customers.size() < manager.max_queue_size:
		spawn_customer()
