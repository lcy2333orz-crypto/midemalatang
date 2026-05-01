extends CharacterBody2D

@export var move_speed: float = 200.0

var nearby_stations: Array[Area2D] = []

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * move_speed
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		try_interact()

	if event.is_action_pressed("toggle_business"):
		try_toggle_business()

func register_nearby_station(station: Area2D) -> void:
	if station not in nearby_stations:
		nearby_stations.append(station)

func unregister_nearby_station(station: Area2D) -> void:
	if station in nearby_stations:
		nearby_stations.erase(station)

func try_interact() -> void:
	print("Nearby stations count: ", nearby_stations.size())

	if nearby_stations.is_empty():
		print("No station nearby")
		return

	var target_station = get_nearest_station()
	if target_station == null:
		print("No valid station nearby")
		return

	print("Trying to interact with: ", target_station.name)

	if target_station.has_method("interact"):
		target_station.interact()

func try_toggle_business() -> void:
	print("Nearby stations count for toggle: ", nearby_stations.size())

	if nearby_stations.is_empty():
		print("No station nearby for toggle")
		return

	var target_station = get_nearest_station()
	if target_station == null:
		print("No valid station nearby for toggle")
		return

	print("Trying to toggle business with: ", target_station.name)

	if target_station.has_method("toggle_business"):
		target_station.toggle_business()
	else:
		print("Target station cannot toggle business.")


func get_nearest_station() -> Area2D:
	var nearest_station: Area2D = null
	var nearest_distance := INF

	for station in nearby_stations:
		if station == null or not is_instance_valid(station):
			continue

		var distance := global_position.distance_squared_to(station.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_station = station

	return nearest_station
