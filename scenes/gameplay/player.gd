extends CharacterBody2D



@export var move_speed: float = 200.0

@export var acceleration: float = 1400.0

@export var deceleration: float = 1800.0

@export var carry_small_item_speed_multiplier: float = 0.95

@export var carry_heavy_item_speed_multiplier: float = 0.75

@export var interact_cooldown_seconds: float = 0.12



var nearby_stations: Array[Area2D] = []

var last_interact_time_msec: int = -999999
var highlighted_station: Area2D = null
var held_order_label: Label = null





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

	_update_held_order_label()





func _unhandled_input(event: InputEvent) -> void:

	if event.is_action_pressed("close_business"):
		if request_restaurant_close_day():
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("interact"):

		try_interact()


func request_restaurant_close_day() -> bool:
	var restaurant_manager = get_tree().get_first_node_in_group("restaurant_game_manager")
	if restaurant_manager == null:
		return false
	if not restaurant_manager.has_method("request_close_day"):
		return false
	restaurant_manager.request_close_day()
	return true



func register_nearby_station(station: Area2D) -> void:

	if station == null or not is_instance_valid(station):

		return



	if station not in nearby_stations:

		nearby_stations.append(station)





func unregister_nearby_station(station: Area2D) -> void:

	if station in nearby_stations:

		nearby_stations.erase(station)

	if highlighted_station == station:
		_set_station_highlight(highlighted_station, false)
		highlighted_station = null





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

	var restaurant_manager = get_tree().get_first_node_in_group("restaurant_game_manager")
	if restaurant_manager != null and restaurant_manager.has_method("get_hand_text"):
		if restaurant_manager.get("held_bowl") != null or restaurant_manager.get("held_pot") != null or restaurant_manager.get("held_dirty_cooker") != null:
			return "heavy"

	return "none"





func get_current_hand_text() -> String:

	var restaurant_manager = get_tree().get_first_node_in_group("restaurant_game_manager")
	if restaurant_manager != null and restaurant_manager.has_method("get_hand_text"):
		return str(restaurant_manager.get_hand_text())

	return ""





func _update_interaction_prompt() -> void:

	var game_ui = get_tree().get_first_node_in_group("game_ui")

	if game_ui == null:

		return



	var target_station = get_best_station()
	_update_highlighted_station(target_station)



	if target_station == null:

		if game_ui.has_method("hide_interaction_prompt"):

			game_ui.hide_interaction_prompt()

		return



	var prompt_text: String = "[E]"

	if target_station.has_method("get_interaction_prompt"):

		prompt_text = str(target_station.get_interaction_prompt())



	if game_ui.has_method("show_interaction_prompt"):

		game_ui.show_interaction_prompt(prompt_text)


func _update_highlighted_station(target_station: Area2D) -> void:
	if highlighted_station == target_station:
		return
	if highlighted_station != null and is_instance_valid(highlighted_station):
		_set_station_highlight(highlighted_station, false)
	highlighted_station = target_station
	if highlighted_station != null and is_instance_valid(highlighted_station):
		_set_station_highlight(highlighted_station, true)


func _set_station_highlight(station: Area2D, value: bool) -> void:
	if station != null and is_instance_valid(station) and station.has_method("set_highlighted"):
		station.set_highlighted(value)





func _update_hand_state_prompt() -> void:

	var game_ui = get_tree().get_first_node_in_group("game_ui")

	if game_ui == null:

		return



	if not game_ui.has_method("update_hand_state"):

		return



	game_ui.update_hand_state(get_current_hand_text())


func _update_held_order_label() -> void:
	_ensure_held_order_label()
	var restaurant_manager = get_tree().get_first_node_in_group("restaurant_game_manager")
	if restaurant_manager == null:
		held_order_label.visible = false
		return

	if not restaurant_manager.has_method("get_hand_text"):
		held_order_label.visible = false
		return

	var hand_text: String = str(restaurant_manager.get_hand_text())
	if hand_text.strip_edges() == "":
		held_order_label.visible = false
		return

	held_order_label.text = hand_text
	held_order_label.visible = true


func _ensure_held_order_label() -> void:
	if held_order_label != null:
		return

	held_order_label = Label.new()
	held_order_label.name = "HeldOrderLabel"
	held_order_label.position = Vector2(-48, -78)
	held_order_label.size = Vector2(96, 24)
	held_order_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	held_order_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	held_order_label.add_theme_font_size_override("font_size", 13)
	held_order_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.62, 1.0))
	held_order_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 1.0))
	held_order_label.add_theme_constant_override("outline_size", 3)
	held_order_label.visible = false
	add_child(held_order_label)
