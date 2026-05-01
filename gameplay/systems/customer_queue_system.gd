class_name CustomerQueueSystem
extends RefCounted

const CustomerOrderState := preload("res://gameplay/models/customer_order_state.gd")

var manager = null
var spawn_policy: Dictionary = {}


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
	if not manager.can_spawn_customers_now():
		return

	print("start spawning customers after opening...")
	for i in range(manager.max_queue_size):
		if manager.queued_customers.size() >= manager.max_queue_size:
			break
		print("spawn attempt after opening: ", i)
		spawn_customer()


func spawn_customer() -> void:
	if not manager.can_spawn_customers_now():
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

	manager.queued_customers.append(customer_instance)
	refresh_queue_positions()

	customer_instance.tree_exited.connect(Callable(manager, "_on_customer_exited").bind(customer_instance))


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
	var idx := manager.queued_customers.find(customer)
	if idx != -1:
		manager.queued_customers.remove_at(idx)
		refresh_queue_positions()


func remove_customer_from_pending(customer: Node) -> void:
	manager.pending_order_system.remove(customer)


func release_counter_customer(customer: Node) -> void:
	remove_customer_from_queue(customer)
	manager.start_spawn_timer_if_needed()


func notify_customer_leaving(customer: Node) -> void:
	var paid_price := 0

	if customer != null and is_instance_valid(customer):
		if CustomerOrderState.is_checked_out(customer) and not CustomerOrderState.is_served(customer):
			paid_price = CustomerOrderState.get_paid_price(customer)

	if paid_price > 0:
		manager.money = max(manager.money - paid_price, 0)
		manager.round_income -= paid_price
		manager.today_income -= paid_price
		print("Refund applied because customer left after payment: ", paid_price)

	var game_ui = manager.get_tree().get_first_node_in_group("game_ui")

	if game_ui:
		game_ui.update_money(manager.money)

	remove_customer_from_queue(customer)
	remove_customer_from_pending(customer)
	manager.remove_customer_from_cooker_slots(customer)

	manager.start_spawn_timer_if_needed()


func on_customer_exited(customer: Node) -> void:
	print("customer exited: ", customer)

	remove_customer_from_queue(customer)
	remove_customer_from_pending(customer)
	manager.remove_customer_from_cooker_slots(customer)

	manager.start_spawn_timer_if_needed()


func on_spawn_timer_timeout() -> void:
	if not manager.can_spawn_customers_now():
		return

	if manager.queued_customers.size() < manager.max_queue_size:
		spawn_customer()
