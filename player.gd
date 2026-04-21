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

	var target_station = nearby_stations[0]
	print("Trying to interact with: ", target_station.name)

	if target_station.has_method("interact"):
		target_station.interact()

func try_toggle_business() -> void:
	print("Nearby stations count for toggle: ", nearby_stations.size())

	if nearby_stations.is_empty():
		print("No station nearby for toggle")
		return

	var target_station = nearby_stations[0]
	print("Trying to toggle business with: ", target_station.name)

	if target_station.has_method("toggle_business"):
		target_station.toggle_business()
	else:
		print("Target station cannot toggle business.")
