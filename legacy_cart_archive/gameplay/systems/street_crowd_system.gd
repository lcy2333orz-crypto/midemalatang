class_name StreetCrowdSystem
extends RefCounted

var manager = null
var spawned_people_count: int = 0
var next_spawn_from_left: bool = true


func bind(game_manager: Node) -> void:
	manager = game_manager


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	if manager == null or not is_instance_valid(manager):
		warnings.append("StreetCrowdSystem is not bound to a valid GameManager.")
		return warnings

	if manager.street_spawn_timer == null:
		warnings.append("StreetCrowdSystem: StreetSpawnTimer is missing.")

	if manager.street_spawn_left == null or manager.street_spawn_right == null:
		warnings.append("StreetCrowdSystem: one or more street spawn markers are missing.")

	if manager.street_exit_left == null or manager.street_exit_right == null:
		warnings.append("StreetCrowdSystem: one or more street exit markers are missing.")

	if manager.passerby_scene == null:
		warnings.append("StreetCrowdSystem: passerby_scene is not assigned.")

	return warnings


func clear_day_state() -> void:
	spawned_people_count = 0
	next_spawn_from_left = true
	stop()


func should_control_customer_spawns() -> bool:
	return manager != null and is_instance_valid(manager) and not RunSetupData.is_tutorial_mode()


func start_day_crowd() -> void:
	if manager == null or not is_instance_valid(manager):
		return

	if manager.street_spawn_timer == null:
		return

	if not manager.street_spawn_timer.is_inside_tree():
		return

	if spawned_people_count >= manager.street_total_spawn_count:
		return

	manager.street_spawn_timer.wait_time = manager.get_street_spawn_interval_seconds()
	manager.street_spawn_timer.start()


func stop() -> void:
	if manager == null or not is_instance_valid(manager):
		return

	if manager.street_spawn_timer != null and is_instance_valid(manager.street_spawn_timer):
		manager.street_spawn_timer.stop()


func on_spawn_timer_timeout() -> void:
	if manager == null or not is_instance_valid(manager):
		return

	if not manager.business_day_system.can_spawn_customers_now():
		return

	if spawned_people_count >= manager.street_total_spawn_count:
		return

	spawned_people_count += 1

	var route_data: Dictionary = _get_next_route_data()
	var should_spawn_customer: bool = should_control_customer_spawns() and _should_spawn_customer()

	if should_spawn_customer and manager.queued_customers.size() < manager.max_queue_size:
		manager.customer_queue_system.spawn_customer(route_data["spawn_position"], route_data["exit_position"])
	else:
		spawn_passerby(route_data["spawn_position"], route_data["exit_position"])

	if spawned_people_count < manager.street_total_spawn_count:
		manager.street_spawn_timer.wait_time = manager.get_street_spawn_interval_seconds()
		manager.street_spawn_timer.start()


func spawn_passerby(spawn_position: Vector2, exit_position: Vector2) -> void:
	if manager.passerby_scene == null:
		return

	var passerby: Node = manager.passerby_scene.instantiate()
	manager.characters_node.add_child(passerby)

	if passerby.has_method("setup"):
		var speed_multiplier: float = randf_range(0.85, 1.15)
		passerby.setup(spawn_position, exit_position, speed_multiplier)
	else:
		passerby.global_position = spawn_position


func _get_next_route_data() -> Dictionary:
	var from_left: bool = next_spawn_from_left
	next_spawn_from_left = not next_spawn_from_left

	var spawn_marker: Marker2D = manager.street_spawn_left if from_left else manager.street_spawn_right
	var cross_exit_marker: Marker2D = manager.street_exit_right if from_left else manager.street_exit_left
	var same_exit_marker: Marker2D = manager.street_exit_left if from_left else manager.street_exit_right
	var exit_marker: Marker2D = same_exit_marker if randf() < manager.street_same_side_exit_ratio else cross_exit_marker

	return {
		"spawn_position": spawn_marker.global_position,
		"exit_position": exit_marker.global_position
	}


func _should_spawn_customer() -> bool:
	if manager.customer_scene == null:
		return false

	return randf() < manager.street_customer_ratio
