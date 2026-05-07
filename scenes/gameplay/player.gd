extends CharacterBody2D

@export var move_speed: float = 200.0
@export var acceleration: float = 1400.0
@export var deceleration: float = 1800.0
@export var carry_small_item_speed_multiplier: float = 0.95
@export var carry_heavy_item_speed_multiplier: float = 0.75
@export var interact_cooldown_seconds: float = 0.12

var nearby_stations: Array[Area2D] = []
var last_interact_time_msec: int = -999999


func _physics_process(delta: float) -> void:
	_cleanup_nearby_stations()

	var direction: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var target_velocity: Vector2 = direction * move_speed * get_current_speed_multiplier()
	var velocity_change_speed: float = acceleration

	if direction == Vector2.ZERO:
		velocity_change_speed = deceleration

	velocity = velocity.move_toward(target_velocity, velocity_change_speed * delta)
	move_and_slide()

	_update_interaction_prompt()
	_update_hand_state_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		try_interact()

	if event.is_action_pressed("toggle_business"):
		try_toggle_business()


func register_nearby_station(station: Area2D) -> void:
	if station == null or not is_instance_valid(station):
		return

	if station not in nearby_stations:
		nearby_stations.append(station)


func unregister_nearby_station(station: Area2D) -> void:
	if station in nearby_stations:
		nearby_stations.erase(station)


func try_interact() -> void:
	if not _can_interact_now():
		return

	print("Nearby stations count: ", nearby_stations.size())

	if nearby_stations.is_empty():
		print("No station nearby")
		return

	var target_station = get_best_station()
	if target_station == null:
		print("No valid station nearby")
		return

	last_interact_time_msec = Time.get_ticks_msec()

	print("Trying to interact with: ", target_station.name)

	if target_station.has_method("interact"):
		target_station.interact()

	_update_interaction_prompt()
	_update_hand_state_prompt()


func try_toggle_business() -> void:
	if not _can_interact_now():
		return

	print("Nearby stations count for toggle: ", nearby_stations.size())

	if nearby_stations.is_empty():
		print("No station nearby for toggle")
		return

	var target_station = get_best_station()
	if target_station == null:
		print("No valid station nearby for toggle")
		return

	last_interact_time_msec = Time.get_ticks_msec()

	print("Trying to toggle business with: ", target_station.name)

	if target_station.has_method("toggle_business"):
		target_station.toggle_business()
	else:
		print("Target station cannot toggle business.")

	_update_interaction_prompt()
	_update_hand_state_prompt()


func _can_interact_now() -> bool:
	var now_msec: int = Time.get_ticks_msec()
	var elapsed_seconds: float = float(now_msec - last_interact_time_msec) / 1000.0
	return elapsed_seconds >= interact_cooldown_seconds


func get_nearest_station() -> Area2D:
	return get_best_station()


func get_best_station() -> Area2D:
	_cleanup_nearby_stations()

	var best_station: Area2D = null
	var best_priority: int = -999999
	var best_distance: float = INF

	for station in nearby_stations:
		if station == null or not is_instance_valid(station):
			continue

		var station_priority: int = 0
		if station.has_method("get_interaction_priority"):
			station_priority = int(station.get_interaction_priority())

		var distance: float = global_position.distance_squared_to(station.global_position)

		if station_priority > best_priority:
			best_station = station
			best_priority = station_priority
			best_distance = distance
			continue

		if station_priority == best_priority and distance < best_distance:
			best_station = station
			best_distance = distance

	return best_station


func _cleanup_nearby_stations() -> void:
	for i in range(nearby_stations.size() - 1, -1, -1):
		var station = nearby_stations[i]

		if station == null or not is_instance_valid(station):
			nearby_stations.remove_at(i)


func get_current_speed_multiplier() -> float:
	var carry_state: String = get_current_carry_state()

	if carry_state == "heavy":
		return carry_heavy_item_speed_multiplier

	if carry_state == "small":
		return carry_small_item_speed_multiplier

	return 1.0


func get_current_carry_state() -> String:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager == null:
		return "none"

	if game_manager.cooking_system != null:
		if str(game_manager.cooking_system.held_staple_food_id) != "":
			return "small"

		if str(game_manager.cooking_system.held_raw_staple_food_id) != "":
			return "small"

	return "none"


func get_current_hand_text() -> String:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager == null:
		return ""

	if game_manager.cooking_system == null:
		return ""

	var held_cooked: String = str(game_manager.cooking_system.held_staple_food_id)
	var held_raw: String = str(game_manager.cooking_system.held_raw_staple_food_id)

	if held_cooked != "":
		return TextDB.get_text("UI_HAND_COOKED") % game_manager.get_ingredient_display_name(held_cooked)

	if held_raw != "":
		return TextDB.get_text("UI_HAND_RAW") % game_manager.get_ingredient_display_name(held_raw)

	return TextDB.get_text("UI_HAND_EMPTY")


func _update_interaction_prompt() -> void:
	var game_ui = get_tree().get_first_node_in_group("game_ui")
	if game_ui == null:
		return

	var target_station = get_best_station()

	if target_station == null:
		if game_ui.has_method("hide_interaction_prompt"):
			game_ui.hide_interaction_prompt()
		return

	var prompt_text: String = TextDB.get_text("UI_PROMPT_INTERACT")
	if target_station.has_method("get_interaction_prompt"):
		prompt_text = str(target_station.get_interaction_prompt())

	if game_ui.has_method("show_interaction_prompt"):
		game_ui.show_interaction_prompt(prompt_text)


func _update_hand_state_prompt() -> void:
	var game_ui = get_tree().get_first_node_in_group("game_ui")
	if game_ui == null:
		return

	if not game_ui.has_method("update_hand_state"):
		return

	game_ui.update_hand_state(get_current_hand_text())
