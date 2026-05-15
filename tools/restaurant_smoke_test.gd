extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_scene_loads()
	if not failures.is_empty():
		_finish()
		return

	await _check_order_loop()
	if not failures.is_empty():
		_finish()
		return

	await _check_delivery_paths()
	if not failures.is_empty():
		_finish()
		return

	await _check_surface_slot_place_take()
	if not failures.is_empty():
		_finish()
		return

	await _check_counter_gives_bowl_to_player()
	if not failures.is_empty():
		_finish()
		return

	await _check_staple_required_before_cooking()
	if not failures.is_empty():
		_finish()
		return

	await _check_staple_interaction_not_blocked_by_counter()
	if not failures.is_empty():
		_finish()
		return

	await _check_two_table_assignment()
	if not failures.is_empty():
		_finish()
		return

	await _check_visible_text_is_ascii()
	if not failures.is_empty():
		_finish()
		return

	await _check_takeout_pickup_slot_completion()
	if not failures.is_empty():
		_finish()
		return

	await _check_overcooked_trash_rule()
	if not failures.is_empty():
		_finish()
		return

	await _check_order_card_destination()
	if not failures.is_empty():
		_finish()
		return

	await _check_restaurant_hud_layout()
	if not failures.is_empty():
		_finish()
		return

	await _check_day_timer_and_summary()
	if not failures.is_empty():
		_finish()
		return

	await _check_manual_close_day()
	if not failures.is_empty():
		_finish()
		return

	await _check_summary_scene()
	if not failures.is_empty():
		_finish()
		return

	_check_staple_timing()
	_finish()


func _check_scene_loads() -> void:
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	if scene_resource == null:
		_fail("scene load", "test_restaurant.tscn could not be loaded")
		return

	var scene: Node = scene_resource.instantiate()

	var required_paths: Array[String] = [
		"Markers/Entrance",
		"Markers/QueueSpots",
		"EnvironmentRoot",
		"GridVisual",
		"SurfaceSlots",
		"PlayerSpawns/PlayerSpawn1",
		"LockedPlaceholders",
		"Stations/IngredientDisplay",
		"Stations/Counter",
		"Stations/DiningTables",
		"Stations/DrinksFridge",
		"Stations/TrashBin",
		"Stations/WaitingOrderArea",
		"Stations/CookerStations/CookerStation1",
		"Stations/StapleArea",
		"Stations/SauceStation",
		"Stations/PackingArea",
		"Stations/StorageArea",
		"RestaurantGameManager"
	]

	for path in required_paths:
		if scene.get_node_or_null(path) == null:
			_fail("scene nodes", "missing %s" % path)

	_assert_node_position(scene, "Characters/Player", _grid(6, 9), "grid player spawn")
	_assert_node_position(scene, "Markers/Entrance", _grid(5, 0), "grid entrance")
	_assert_node_position(scene, "Markers/Exit", _grid(5, 0), "grid exit")
	_assert_node_position(scene, "Markers/CounterSpot", _grid(6, 7), "grid counter spot")
	_assert_node_position(scene, "Stations/Counter", _grid(6, 8), "grid counter")
	_assert_node_position(scene, "Stations/WaitingOrderArea", _grid(7, 8), "grid waiting area")
	_assert_node_position(scene, "Stations/CookerStations/CookerStation1", _grid(3, 15), "grid cooker 1")
	_assert_node_position(scene, "Stations/CookerStations/CookerStation2", _grid(5, 15), "grid cooker 2")
	_assert_node_position(scene, "Stations/SauceStation", _grid(9, 13), "grid sauce")
	_assert_node_position(scene, "Stations/PackingArea", _grid(1, 12), "grid packing")
	_assert_node_position(scene, "SurfaceSlots/TakeoutPickupSlot1", _grid(3, 8), "grid takeout slot 1")
	_assert_node_position(scene, "SurfaceSlots/TakeoutPickupSlot2", _grid(4, 8), "grid takeout slot 2")
	_assert_node_position(scene, "LockedPlaceholders/TakeoutPickupTable2", _grid(4, 8), "grid takeout placeholder 2")
	_assert_node_position(scene, "Stations/DiningTables/DiningTable1", _grid(9, 4), "grid table 1")
	_assert_node_position(scene, "Stations/DiningTables/DiningTable2", _grid(9, 6), "grid table 2")
	_assert_greybox_labels(scene)
	_assert_independent_cell_bodies(scene)
	_assert_character_scale(scene)

	scene.free()
	_pass("scene load")


func _assert_greybox_labels(scene: Node) -> void:
	var expected_labels: Dictionary = {
		"GridVisual/GridLineV0": "",
		"GridVisual/GridLineV15": "",
		"GridVisual/GridLineH0": "",
		"GridVisual/GridLineH9": "",
		"PlayerSpawns/PlayerSpawn1/Label": "P1 SPAWN",
		"PlayerSpawns/PlayerSpawn2/Label": "P2 SPAWN",
		"PlayerSpawns/PlayerSpawn3/Label": "P3 SPAWN",
		"PlayerSpawns/PlayerSpawn4/Label": "P4 SPAWN",
		"LockedPlaceholders/DoorCell1/Label": "DOOR A r5c1",
		"LockedPlaceholders/DoorCell2/Label": "DOOR B r6c1",
		"LockedPlaceholders/IngredientDisplay2/Label": "ING 2 r1c2",
		"LockedPlaceholders/IngredientDisplay3/Label": "ING 3 r1c3",
		"LockedPlaceholders/IngredientDisplay4Locked/Label": "ING LOCK r1c4",
		"LockedPlaceholders/DrinkFridge2Locked/Label": "DRINK LOCK r1c6",
		"LockedPlaceholders/Cooker3Locked/Label": "POT LOCK r7c15",
		"LockedPlaceholders/SauceStationMixed/Label": "SAUCE MIX r9c14",
		"LockedPlaceholders/PackingBagArea/Label": "BAG AREA r1c13",
		"LockedPlaceholders/TakeoutPickupTable2/Label": "TAKEOUT 2 r4c8",
		"SurfaceSlots/TakeoutPickupSlot1/Label": "TAKEOUT 1",
		"SurfaceSlots/TakeoutPickupSlot2/Label": "TAKEOUT 2",
		"LockedPlaceholders/CustomerTrashBin/Label": "TRASH C r9c1",
		"LockedPlaceholders/DrinkStorage/Label": "DRINK BOX r9c11",
		"Stations/IngredientDisplay/Label": "ING 1",
		"Stations/DrinksFridge/Label": "DRINK 1",
		"Stations/Counter/Label": "COUNTER",
		"Stations/StapleArea/Label": "STAPLE",
		"Stations/CookerStations/CookerStation1/Label": "POT 1",
		"Stations/CookerStations/CookerStation2/Label": "POT 2",
		"Stations/CookerStations/CookerStation1/StatusLabel": "EMPTY",
		"Stations/CookerStations/CookerStation2/StatusLabel": "EMPTY",
		"Stations/SauceStation/Label": "CHILI",
		"Stations/PackingArea/Label": "PACK MACHINE",
		"Stations/TakeoutPickup/Label": "TAKEOUT 1",
		"Stations/TrashBin/Label": "TRASH K",
		"Stations/StorageArea/Label": "FRIDGE",
		"Stations/DiningTables/DiningTable1/Label": "DINE 1",
		"Stations/DiningTables/DiningTable2/Label": "DINE 2",
		"Stations/WaitingOrderArea/Label": "WAITING",
		"SurfaceSlots/SurfaceSlot_r1c8/Label": "SURF r1c8",
		"SurfaceSlots/SurfaceSlot_r1c9/Label": "SURF r1c9",
		"SurfaceSlots/SurfaceSlot_r1c10/Label": "SURF r1c10",
		"SurfaceSlots/SurfaceSlot_r1c11/Label": "SURF r1c11",
		"SurfaceSlots/SurfaceSlot_r2c10/Label": "SURF r2c10",
		"SurfaceSlots/SurfaceSlot_r3c10/Label": "SURF r3c10",
		"SurfaceSlots/SurfaceSlot_r4c10/Label": "SURF r4c10",
		"SurfaceSlots/SurfaceSlot_r5c10/Label": "SURF r5c10",
		"SurfaceSlots/SurfaceSlot_r6c10/Label": "SURF r6c10",
		"SurfaceSlots/SurfaceSlot_r1c15/Label": "SURF r1c15",
		"SurfaceSlots/SurfaceSlot_r2c15/Label": "SURF r2c15",
		"SurfaceSlots/SurfaceSlot_r4c15/Label": "SURF r4c15",
		"SurfaceSlots/SurfaceSlot_r6c15/Label": "SURF r6c15",
		"SurfaceSlots/SurfaceSlot_r8c15/Label": "SURF r8c15",
		"SurfaceSlots/SurfaceSlot_r9c15/Label": "SURF r9c15",
	}

	for path in expected_labels:
		var node: Node = scene.get_node_or_null(path)
		if node == null:
			_fail("greybox labels", "missing %s" % path)
			continue
		var expected: String = expected_labels[path]
		if expected == "":
			continue
		var label: Label = node as Label
		if label == null:
			_fail("greybox labels", "%s is not a Label" % path)
			continue
		if label.text != expected:
			_fail("greybox labels", "%s expected '%s' but was '%s'" % [path, expected, label.text])


func _assert_independent_cell_bodies(scene: Node) -> void:
	var surface_slots: Array[String] = [
		"SurfaceSlots/SurfaceSlot_r1c8",
		"SurfaceSlots/SurfaceSlot_r1c9",
		"SurfaceSlots/SurfaceSlot_r1c10",
		"SurfaceSlots/SurfaceSlot_r1c11",
		"SurfaceSlots/SurfaceSlot_r2c10",
		"SurfaceSlots/SurfaceSlot_r3c10",
		"SurfaceSlots/SurfaceSlot_r4c10",
		"SurfaceSlots/SurfaceSlot_r5c10",
		"SurfaceSlots/SurfaceSlot_r6c10",
		"SurfaceSlots/SurfaceSlot_r1c15",
		"SurfaceSlots/SurfaceSlot_r2c15",
		"SurfaceSlots/SurfaceSlot_r4c15",
		"SurfaceSlots/SurfaceSlot_r6c15",
		"SurfaceSlots/SurfaceSlot_r8c15",
		"SurfaceSlots/SurfaceSlot_r9c15",
		"SurfaceSlots/TakeoutPickupSlot1",
		"SurfaceSlots/TakeoutPickupSlot2",
	]
	for path in surface_slots:
		_assert_solid_independent_cell(scene, path, true)

	var placeholders: Array[String] = [
		"LockedPlaceholders/IngredientDisplay2",
		"LockedPlaceholders/IngredientDisplay3",
		"LockedPlaceholders/IngredientDisplay4Locked",
		"LockedPlaceholders/DrinkFridge2Locked",
		"LockedPlaceholders/Cooker3Locked",
		"LockedPlaceholders/SauceStationMixed",
		"LockedPlaceholders/PackingBagArea",
		"LockedPlaceholders/TakeoutPickupTable2",
		"LockedPlaceholders/CustomerTrashBin",
		"LockedPlaceholders/DrinkStorage",
	]
	for path in placeholders:
		_assert_solid_independent_cell(scene, path, false)


func _assert_solid_independent_cell(scene: Node, path: String, requires_interaction: bool) -> void:
	var cell: Node = scene.get_node_or_null(path)
	if cell == null:
		_fail("independent cells", "missing %s" % path)
		return

	var visual: Polygon2D = cell.get_node_or_null("Visual") as Polygon2D
	if visual == null:
		_fail("independent cells", "%s missing Visual" % path)
	elif visual.color.a < 0.8:
		_fail("independent cells", "%s Visual alpha %.2f is too low" % [path, visual.color.a])

	if cell.get_node_or_null("Label") == null:
		_fail("independent cells", "%s missing Label" % path)

	var solid_body: StaticBody2D = cell.get_node_or_null("SolidBody") as StaticBody2D
	if solid_body == null:
		_fail("independent cells", "%s missing SolidBody" % path)
		return

	var solid_shape: CollisionShape2D = solid_body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if solid_shape == null:
		_fail("independent cells", "%s missing SolidBody/CollisionShape2D" % path)
	elif solid_shape.shape == null:
		_fail("independent cells", "%s SolidBody shape is null" % path)
	else:
		var rect: RectangleShape2D = solid_shape.shape as RectangleShape2D
		if rect != null and (rect.size.x > 48.0 or rect.size.y > 48.0):
			_fail("independent cells", "%s SolidBody too large: %s" % [path, rect.size])

	if requires_interaction:
		var interaction_area: Area2D = cell.get_node_or_null("InteractionArea") as Area2D
		if interaction_area == null:
			_fail("independent cells", "%s missing InteractionArea" % path)
			return
		var interaction_shape: CollisionShape2D = interaction_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if interaction_shape == null or interaction_shape.shape == null:
			_fail("independent cells", "%s missing InteractionArea/CollisionShape2D" % path)


func _assert_character_scale(scene: Node) -> void:
	var player_collision: CollisionShape2D = scene.get_node_or_null("Characters/Player/CollisionShape2D") as CollisionShape2D
	_assert_capsule_shape(player_collision, "player collision", 8.0, 24.0)

	var player_interaction: CollisionShape2D = scene.get_node_or_null("Characters/Player/InteractionArea/CollisionShape2D") as CollisionShape2D
	var player_circle: CircleShape2D = null
	if player_interaction != null:
		player_circle = player_interaction.shape as CircleShape2D
	if player_circle == null:
		_fail("character scale", "player interaction shape is not a circle")
	elif player_circle.radius > 22.0:
		_fail("character scale", "player interaction radius %.1f is too large" % player_circle.radius)

	var player_visual: Polygon2D = scene.get_node_or_null("Characters/Player/Visual/Polygon2D") as Polygon2D
	_assert_polygon_size(player_visual, "player visual", Vector2(22.0, 26.0))

	var customer_scene: PackedScene = load("res://scenes/gameplay/restaurant/restaurant_customer.tscn")
	var customer: Node = customer_scene.instantiate()
	customer.call("_ensure_visuals")

	var customer_collision: CollisionShape2D = customer.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_assert_capsule_shape(customer_collision, "customer collision", 8.0, 24.0)

	var customer_speed: float = float(customer.get("move_speed"))
	if not is_equal_approx(customer_speed, 80.0):
		_fail("character scale", "customer move_speed expected 80.0 but was %.1f" % customer_speed)

	var customer_visual_root: Node = customer.get_node_or_null("Visual")
	var customer_visual: Polygon2D = null
	if customer_visual_root != null and customer_visual_root.get_child_count() > 0:
		customer_visual = customer_visual_root.get_child(0) as Polygon2D
	_assert_polygon_size(customer_visual, "customer visual", Vector2(20.0, 26.0))
	customer.free()


func _assert_capsule_shape(collision_shape: CollisionShape2D, label: String, max_radius: float, max_height: float) -> void:
	if collision_shape == null:
		_fail("character scale", "%s missing CollisionShape2D" % label)
		return
	var capsule: CapsuleShape2D = collision_shape.shape as CapsuleShape2D
	if capsule == null:
		_fail("character scale", "%s is not a CapsuleShape2D" % label)
		return
	if capsule.radius > max_radius or capsule.height > max_height:
		_fail("character scale", "%s too large: radius %.1f height %.1f" % [label, capsule.radius, capsule.height])


func _assert_polygon_size(polygon_node: Polygon2D, label: String, max_size: Vector2) -> void:
	if polygon_node == null:
		_fail("character scale", "%s missing Polygon2D" % label)
		return
	var size: Vector2 = _get_polygon_size(polygon_node.polygon)
	if size.x > max_size.x or size.y > max_size.y:
		_fail("character scale", "%s too large: %s" % [label, size])


func _get_polygon_size(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var min_point: Vector2 = points[0]
	var max_point: Vector2 = points[0]
	for point in points:
		min_point.x = min(min_point.x, point.x)
		min_point.y = min(min_point.y, point.y)
		max_point.x = max(max_point.x, point.x)
		max_point.y = max(max_point.y, point.y)
	return max_point - min_point


func _grid(row: int, col: int) -> Vector2:
	return Vector2(142.5, 130.0) + Vector2((float(col) - 0.5) * 45.0, (float(row) - 0.5) * 45.0)


func _assert_node_position(scene: Node, path: String, expected: Vector2, step_name: String) -> void:
	var node: Node2D = scene.get_node_or_null(path) as Node2D
	if node == null:
		_fail(step_name, "missing %s" % path)
		return
	if node.position.distance_to(expected) > 1.0:
		_fail(step_name, "%s expected %s but was %s" % [path, expected, node.position])


func _is_ascii(text: String) -> bool:
	for i in range(text.length()):
		if text.unicode_at(i) > 127:
			return false
	return true


func _check_order_loop() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("order loop", "restaurant manager was not found")
		scene.queue_free()
		return

	var completed: bool = await manager.force_complete_one_order_for_smoke()
	if not completed:
		_fail("order loop", "could not complete a restaurant order")
		scene.queue_free()
		return

	if int(manager.completed_orders) <= 0:
		_fail("order loop", "completed order count did not increase")
		scene.queue_free()
		return
	if int(manager.money_today) != 10:
		_fail("order loop", "completed order did not add money")
		scene.queue_free()
		return
	if int(manager.failed_orders) != 0:
		_fail("order loop", "completed order should not add failures")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("order loop")


func _check_delivery_paths() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("delivery paths", "restaurant manager was not found")
		scene.queue_free()
		return

	var takeout_bowl: OrderBowl = OrderBowl.new()
	scene.add_child(takeout_bowl)
	takeout_bowl.setup_order(501, {"spinach": 1}, "noodle", "hot", "takeout", 0)
	takeout_bowl.status = OrderBowl.STATUS_COOKED
	takeout_bowl.add_required_staple()
	manager.held_bowl = takeout_bowl
	manager.interact_sauce_station()
	manager.interact_packing_area()
	manager.interact_surface_slot("TakeoutPickupSlot1")
	if manager.held_bowl != null or int(manager.completed_orders) != 1:
		_fail("delivery paths", "packed takeout should complete at takeout pickup slot")
		scene.queue_free()
		return

	var dine_bowl: OrderBowl = OrderBowl.new()
	scene.add_child(dine_bowl)
	dine_bowl.setup_order(502, {"spinach": 1}, "noodle", "hot", "dine_in", 2)
	dine_bowl.status = OrderBowl.STATUS_COOKED
	dine_bowl.add_required_staple()
	manager.held_bowl = dine_bowl
	manager.interact_sauce_station()
	manager.interact_delivery_table(1)
	if manager.held_bowl == null:
		_fail("delivery paths", "dine-in should not complete at the wrong table")
		scene.queue_free()
		return
	manager.interact_delivery_table(2)
	if manager.held_bowl != null or int(manager.completed_orders) != 2:
		_fail("delivery paths", "dine-in should complete at the assigned table")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("delivery paths")


func _check_surface_slot_place_take() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("surface slot", "restaurant manager was not found")
		scene.queue_free()
		return

	var bowl: OrderBowl = OrderBowl.new()
	scene.add_child(bowl)
	bowl.setup_order(601, {"spinach": 1}, "none", "mild", "dine_in", 1)
	manager._hold_bowl(bowl)
	manager.interact_surface_slot("SurfaceSlot_r1c8")

	var slot: SurfaceSlot = manager._get_surface_slot("SurfaceSlot_r1c8")
	if manager.held_bowl != null or slot == null or slot.get_stored_bowl() != bowl:
		_fail("surface slot", "bowl was not placed on surface slot")
		scene.queue_free()
		return
	if not manager._get_tracked_order_bowls().has(bowl):
		_fail("surface slot", "placed bowl was not tracked")
		scene.queue_free()
		return

	manager.interact_surface_slot("SurfaceSlot_r1c8")
	if manager.held_bowl != bowl or not slot.is_empty():
		_fail("surface slot", "bowl was not picked back up from surface slot")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("surface slot")


func _check_counter_gives_bowl_to_player() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("counter handoff", "restaurant manager was not found")
		scene.queue_free()
		return

	var guard: int = 0
	while manager._get_counter_customer() == null and guard < 360:
		await process_frame
		guard += 1

	manager.interact_counter()
	if manager.held_bowl == null:
		_fail("counter handoff", "counter should give order bowl directly to player")
		scene.queue_free()
		return
	if manager.waiting_area.bowls.has(manager.held_bowl):
		_fail("counter handoff", "new order should not enter waiting area")
		scene.queue_free()
		return
	if not manager._get_tracked_order_bowls().has(manager.held_bowl):
		_fail("counter handoff", "new held order should be tracked")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("counter handoff")


func _check_staple_required_before_cooking() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("staple gate", "restaurant manager was not found")
		scene.queue_free()
		return

	var bowl: OrderBowl = OrderBowl.new()
	scene.add_child(bowl)
	bowl.setup_order(602, {"spinach": 1}, "noodle", "mild", "takeout", 0)
	manager._hold_bowl(bowl)
	manager.interact_cooker(manager.cooker_1)
	if manager.cooker_1.active_bowl != null or manager.held_bowl != bowl:
		_fail("staple gate", "order without staple should not enter cooker")
		scene.queue_free()
		return

	manager.interact_staple_cabinet()
	manager.interact_cooker(manager.cooker_1)
	if manager.cooker_1.active_bowl != bowl or manager.held_bowl != null:
		_fail("staple gate", "order with staple should enter cooker")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("staple gate")


func _check_staple_interaction_not_blocked_by_counter() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("staple interaction", "restaurant manager was not found")
		scene.queue_free()
		return

	var counter_area: RestaurantStationArea = scene.get_node_or_null("Stations/Counter/InteractionArea") as RestaurantStationArea
	var staple_area: RestaurantStationArea = scene.get_node_or_null("Stations/StapleArea/InteractionArea") as RestaurantStationArea
	var counter_shape: CollisionShape2D = scene.get_node_or_null("Stations/Counter/InteractionArea/CollisionShape2D") as CollisionShape2D
	var staple_shape: CollisionShape2D = scene.get_node_or_null("Stations/StapleArea/InteractionArea/CollisionShape2D") as CollisionShape2D
	if counter_area == null or staple_area == null or counter_shape == null or staple_shape == null:
		_fail("staple interaction", "missing counter or staple interaction area")
		scene.queue_free()
		return

	if counter_shape.position.x <= 0.0 or staple_shape.position.x <= 0.0:
		_fail("staple interaction", "counter and staple interaction shapes should be offset to the right")
		scene.queue_free()
		return

	var counter_rect: RectangleShape2D = counter_shape.shape as RectangleShape2D
	var staple_rect: RectangleShape2D = staple_shape.shape as RectangleShape2D
	if counter_rect == null or staple_rect == null or counter_rect.size.x > 60.0 or staple_rect.size.x > 60.0:
		_fail("staple interaction", "counter and staple interaction shapes should be small")
		scene.queue_free()
		return
	if counter_area.get_interaction_priority() != 120 or staple_area.get_interaction_priority() != 125:
		_fail("staple interaction", "counter and staple priorities should be 120/125")
		scene.queue_free()
		return

	var bowl: OrderBowl = OrderBowl.new()
	scene.add_child(bowl)
	bowl.setup_order(604, {"spinach": 1}, "noodle", "mild", "takeout", 0)
	manager._hold_bowl(bowl)
	manager.interact_staple_cabinet()
	if not bool(bowl.staple_added):
		_fail("staple interaction", "staple cabinet did not add required staple")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("staple interaction")


func _check_two_table_assignment() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("table assignment", "restaurant manager was not found")
		scene.queue_free()
		return

	var seen: Dictionary = {}
	for id in range(1, 8):
		manager.next_order_id = id
		var table_id: int = manager._next_table_id()
		seen[table_id] = true
		if table_id < 1 or table_id > 2:
			_fail("table assignment", "table assignment returned %d" % table_id)
			scene.queue_free()
			return
	if not seen.has(1) or not seen.has(2) or seen.has(3):
		_fail("table assignment", "table assignment should use only tables 1 and 2")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("table assignment")


func _check_visible_text_is_ascii() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("ascii text", "restaurant manager was not found")
		scene.queue_free()
		return

	var bowl: OrderBowl = OrderBowl.new()
	scene.add_child(bowl)
	bowl.setup_order(605, {"spinach": 1}, "noodle", "mild", "takeout", 0)
	manager._hold_bowl(bowl)
	var ui: RestaurantUI = RestaurantUI.new()
	get_root().add_child(ui)
	await process_frame
	ui.update_time(12.4)
	var time_label: Label = ui.get("time_label") as Label

	var texts: Array[String] = [
		bowl.get_order_status_text(),
		bowl.get_cooker_timer_text(),
		manager.get_hand_text(),
		time_label.text if time_label != null else ""
	]
	bowl.status = OrderBowl.STATUS_COOKING
	bowl.update_cooking(8.2)
	texts.append(bowl.get_order_status_text())
	texts.append(bowl.get_cooker_timer_text())
	bowl.update_cooking(6.2)
	texts.append(bowl.get_order_status_text())
	texts.append(bowl.get_cooker_timer_text())

	for text in texts:
		if not _is_ascii(text):
			_fail("ascii text", "visible text should be ASCII: %s" % text)
			ui.queue_free()
			scene.queue_free()
			return

	ui.queue_free()
	scene.queue_free()
	_pass("ascii text")


func _check_takeout_pickup_slot_completion() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("takeout slot", "restaurant manager was not found")
		scene.queue_free()
		return

	var bowl: OrderBowl = OrderBowl.new()
	scene.add_child(bowl)
	bowl.setup_order(603, {"spinach": 1}, "none", "mild", "takeout", 0)
	bowl.status = OrderBowl.STATUS_PACKED
	manager._hold_bowl(bowl)
	var completed_before: int = int(manager.completed_orders)
	manager.interact_surface_slot("TakeoutPickupSlot1")

	var slot: SurfaceSlot = manager._get_surface_slot("TakeoutPickupSlot1")
	if manager.held_bowl != null:
		_fail("takeout slot", "completed takeout should leave player hands")
		scene.queue_free()
		return
	if slot == null or not slot.is_empty():
		_fail("takeout slot", "takeout slot should be empty after completion")
		scene.queue_free()
		return
	if int(manager.completed_orders) != completed_before + 1 or int(manager.money_today) != 10:
		_fail("takeout slot", "takeout slot completion did not update totals")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("takeout slot")


func _check_overcooked_trash_rule() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("overcooked trash", "restaurant manager was not found")
		scene.queue_free()
		return

	var guard: int = 0
	while manager._get_counter_customer() == null and guard < 360:
		await process_frame
		guard += 1

	var customer: Node = manager._get_counter_customer()
	if customer == null:
		_fail("overcooked trash", "no customer reached the counter")
		scene.queue_free()
		return
	if customer.get_node_or_null("OrderBowl") != null:
		_fail("overcooked trash", "customer should not display an order bowl")
		scene.queue_free()
		return

	manager.interact_counter()
	if manager.held_bowl != null and not manager.held_bowl.is_staple_ready_for_cooking():
		manager.interact_staple_cabinet()
	manager.interact_cooker(manager.cooker_1)
	if manager.cooker_1.active_bowl == null:
		_fail("overcooked trash", "order did not enter cooker")
		scene.queue_free()
		return

	manager.cooker_1.active_bowl.update_cooking(14.2)
	if not manager.cooker_1.active_bowl.is_overcooked():
		_fail("overcooked trash", "order did not overcook")
		scene.queue_free()
		return

	manager.interact_cooker(manager.cooker_1)
	if manager.held_bowl != null:
		_fail("overcooked trash", "overcooked order should not enter held_bowl")
		scene.queue_free()
		return
	if manager.held_dirty_cooker != manager.cooker_1:
		_fail("overcooked trash", "overcooked cooker should become the held dirty cooker")
		scene.queue_free()
		return
	if manager.cooker_1.active_bowl == null:
		_fail("overcooked trash", "overcooked order should stay in cooker until trash")
		scene.queue_free()
		return

	var completed_before: int = int(manager.completed_orders)
	var failed_before: int = int(manager.failed_orders)
	manager.interact_sauce_station()
	if manager.held_dirty_cooker != manager.cooker_1:
		_fail("overcooked trash", "sauce station should not clear dirty cooker")
		scene.queue_free()
		return

	manager.interact_trash_bin()
	if manager.held_dirty_cooker != null:
		_fail("overcooked trash", "trash bin did not clear held dirty cooker")
		scene.queue_free()
		return
	if manager.cooker_1.active_bowl != null:
		_fail("overcooked trash", "trash bin did not clear the overcooked cooker")
		scene.queue_free()
		return
	if int(manager.completed_orders) != completed_before:
		_fail("overcooked trash", "discarded overcooked order should not count as completed")
		scene.queue_free()
		return
	if int(manager.failed_orders) != failed_before + 1:
		_fail("overcooked trash", "discarded overcooked order should count as failed")
		scene.queue_free()
		return

	var bowl_scene: PackedScene = load("res://scenes/gameplay/restaurant/order_bowl.tscn")
	var bowl_1: OrderBowl = bowl_scene.instantiate() as OrderBowl
	var bowl_2: OrderBowl = bowl_scene.instantiate() as OrderBowl
	bowl_1.setup_order(301, {"spinach": 1}, "noodle", "hot", "takeout", 0)
	bowl_2.setup_order(302, {"spinach": 1}, "noodle", "hot", "takeout", 0)
	bowl_1.add_required_staple()
	bowl_2.add_required_staple()
	manager.cooker_1.add_bowl(bowl_1)
	manager.cooker_2.add_bowl(bowl_2)
	manager.cooker_1.active_bowl.update_cooking(14.2)
	manager.cooker_2.active_bowl.update_cooking(14.2)
	manager.interact_cooker(manager.cooker_2)
	if manager.held_dirty_cooker != manager.cooker_2:
		_fail("overcooked trash", "player should hold the overcooked cooker they interacted with")
		scene.queue_free()
		return
	manager.interact_trash_bin()
	if manager.cooker_2.active_bowl != null:
		_fail("overcooked trash", "trash should clear the held dirty cooker")
		scene.queue_free()
		return
	if manager.cooker_1.active_bowl == null:
		_fail("overcooked trash", "trash should not clear a different overcooked cooker")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("overcooked trash")


func _check_order_card_destination() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("order card destination", "restaurant manager was not found")
		scene.queue_free()
		return

	var takeout_bowl: OrderBowl = OrderBowl.new()
	takeout_bowl.setup_order(401, {"spinach": 1}, "noodle", "hot", "takeout", 0)
	var takeout_text: String = manager._get_order_card_text(takeout_bowl)
	if not takeout_text.contains("TAKEOUT 1/2"):
		_fail("order card destination", "takeout card should show pickup destination")
		scene.queue_free()
		return
	if not takeout_text.contains("#401") or not takeout_text.contains("100%"):
		_fail("order card destination", "takeout card should keep id and patience")
		scene.queue_free()
		return

	var dine_bowl: OrderBowl = OrderBowl.new()
	dine_bowl.setup_order(402, {"spinach": 1}, "noodle", "hot", "dine_in", 2)
	var dine_text: String = manager._get_order_card_text(dine_bowl)
	if not dine_text.contains("DINE 2"):
		_fail("order card destination", "dine-in card should show table destination")
		scene.queue_free()
		return
	if not dine_text.contains("#402") or not dine_text.contains("100%"):
		_fail("order card destination", "dine-in card should keep id and patience")
		scene.queue_free()
		return

	takeout_bowl.queue_free()
	dine_bowl.queue_free()
	scene.queue_free()
	_pass("order card destination")


func _check_restaurant_hud_layout() -> void:
	var ui: RestaurantUI = RestaurantUI.new()
	get_root().add_child(ui)
	await process_frame

	var orders_bar: HBoxContainer = ui.get("orders_bar") as HBoxContainer
	var time_label: Label = ui.get("time_label") as Label
	var status_label: Label = ui.get("status_label") as Label
	var hand_label: Label = ui.get("hand_label") as Label
	var toast_label: Label = ui.get("toast_label") as Label
	if orders_bar == null or time_label == null or status_label == null or hand_label == null or toast_label == null:
		_fail("hud layout", "restaurant HUD widgets were not created")
		ui.queue_free()
		return

	if orders_bar.position.x > 12.0 or orders_bar.position.y > 12.0:
		_fail("hud layout", "orders bar should start at the top-left")
		ui.queue_free()
		return
	if time_label.position.x < 760.0 or time_label.position.y > 12.0:
		_fail("hud layout", "time label should sit at the top-right")
		ui.queue_free()
		return

	ui.update_status("debug status should stay hidden")
	if bool(status_label.visible):
		_fail("hud layout", "status label should be hidden in the simplified HUD")
		ui.queue_free()
		return
	ui.update_hand_state("Holding #001")
	if bool(hand_label.visible):
		_fail("hud layout", "hand label should stay hidden in the simplified HUD")
		ui.queue_free()
		return
	if not hand_label.text.contains("#001"):
		_fail("hud layout", "hidden hand label should keep text for compatibility")
		ui.queue_free()
		return

	ui.show_toast("Closed: no new customers.", 1.8)
	if not bool(toast_label.visible) or not toast_label.text.contains("Closed"):
		_fail("hud layout", "toast should show manual close feedback")
		ui.queue_free()
		return

	ui.update_time(12.4)
	if not time_label.text.contains("13s"):
		_fail("hud layout", "time label should round up remaining seconds")
		ui.queue_free()
		return

	ui.update_order_cards(["#001\nA\n100%", "#002\nB\n80%", "#003\nC\n60%"])
	if orders_bar.get_child_count() != 3:
		_fail("hud layout", "order cards should be added horizontally")
		ui.queue_free()
		return
	var first_card_text: String = _get_card_label_text(orders_bar.get_child(0))
	if not first_card_text.contains("#001"):
		_fail("hud layout", "first order card should stay at the left")
		ui.queue_free()
		return

	ui.update_order_cards(["#002\nB\n80%", "#003\nC\n60%"])
	if orders_bar.get_child_count() != 2:
		_fail("hud layout", "removed order should compact the row")
		ui.queue_free()
		return
	var compacted_first_text: String = _get_card_label_text(orders_bar.get_child(0))
	if not compacted_first_text.contains("#002"):
		_fail("hud layout", "remaining orders should shift left after removal")
		ui.queue_free()
		return

	ui.queue_free()
	_pass("hud layout")


func _get_card_label_text(card: Node) -> String:
	if card == null:
		return ""
	var labels: Array[Node] = card.find_children("*", "Label", true, false)
	for label_node in labels:
		var label: Label = label_node as Label
		if label != null and label.text.strip_edges() != "":
			return label.text
	return ""


func _check_day_timer_and_summary() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("day timer", "restaurant manager was not found")
		scene.queue_free()
		return

	manager.auto_change_to_summary = false
	manager.spawn_elapsed = 999.0
	var spawned_before_close: int = int(manager.spawn_count)
	manager.day_time_remaining = 0.01
	manager.is_day_open = true
	await process_frame

	if bool(manager.is_day_open):
		_fail("day timer", "day did not close when timer reached zero")
		scene.queue_free()
		return
	if int(manager.spawn_count) != spawned_before_close:
		_fail("day timer", "new customer spawned after day closed")
		scene.queue_free()
		return

	manager.queued_customers.clear()
	manager.waiting_customers_by_order_id.clear()
	for customer_node in get_nodes_in_group("restaurant_customers"):
		if customer_node != null and is_instance_valid(customer_node):
			customer_node.queue_free()
	manager.held_bowl = null
	manager.held_dirty_cooker = null
	manager.waiting_area.bowls.clear()
	for cooker in [manager.cooker_1, manager.cooker_2]:
		if cooker != null:
			var cleared_bowl: OrderBowl = cooker.clear_active_bowl()
			if cleared_bowl != null:
				cleared_bowl.queue_free()

	await process_frame
	await process_frame

	if not bool(manager.summary_transition_requested):
		_fail("day timer", "empty closed day did not request night summary")
		scene.queue_free()
		return
	if RestaurantRunState.last_day_summary.is_empty():
		_fail("day timer", "night summary data was not recorded")
		scene.queue_free()
		return
	if int(RestaurantRunState.last_day_summary.get("day", 0)) != 1:
		_fail("day timer", "summary day was not recorded")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("day timer")


func _check_manual_close_day() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("manual close", "restaurant manager was not found")
		scene.queue_free()
		return

	manager.auto_change_to_summary = false
	manager.spawn_elapsed = 999.0
	var spawned_before_close: int = int(manager.spawn_count)
	manager.request_close_day()

	if bool(manager.is_day_open):
		_fail("manual close", "request_close_day did not close the day")
		scene.queue_free()
		return
	if float(manager.day_time_remaining) != 0.0:
		_fail("manual close", "request_close_day did not clear remaining time")
		scene.queue_free()
		return
	if float(manager.spawn_elapsed) != 0.0:
		_fail("manual close", "request_close_day did not clear spawn timer")
		scene.queue_free()
		return

	manager.spawn_elapsed = 999.0
	await process_frame
	if int(manager.spawn_count) != spawned_before_close:
		_fail("manual close", "manual close allowed another customer to spawn")
		scene.queue_free()
		return

	manager.queued_customers.clear()
	manager.waiting_customers_by_order_id.clear()
	for customer_node in get_nodes_in_group("restaurant_customers"):
		if customer_node != null and is_instance_valid(customer_node):
			customer_node.queue_free()
	manager.held_bowl = null
	manager.held_dirty_cooker = null
	manager.waiting_area.bowls.clear()
	for cooker in [manager.cooker_1, manager.cooker_2]:
		if cooker != null:
			var cleared_bowl: OrderBowl = cooker.clear_active_bowl()
			if cleared_bowl != null:
				cleared_bowl.queue_free()

	await process_frame
	await process_frame

	if not bool(manager.summary_transition_requested):
		_fail("manual close", "empty manually closed day did not request summary")
		scene.queue_free()
		return
	if RestaurantRunState.last_day_summary.is_empty():
		_fail("manual close", "manual close did not record summary data")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("manual close")


func _check_summary_scene() -> void:
	RestaurantRunState.start_new_run(2)
	RestaurantRunState.record_day({
		"day": 1,
		"max_days": 2,
		"completed_orders": 2,
		"failed_orders": 1,
		"queue_lost_customers": 1,
		"money_today": 20,
		"score_today": 7,
		"review_text": "评价：还能再稳一点。"
	})

	var scene_resource: PackedScene = load("res://scenes/restaurant_summary/restaurant_night_summary.tscn")
	if scene_resource == null:
		_fail("summary scene", "night summary scene could not be loaded")
		return

	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame

	var continue_button: Button = scene.get("continue_button") as Button
	var summary_label: Label = scene.get("summary_label") as Label
	if continue_button == null or summary_label == null:
		_fail("summary scene", "summary widgets were not created")
		scene.queue_free()
		return
	if continue_button.text != "继续下一天":
		_fail("summary scene", "incomplete run should continue to next day")
		scene.queue_free()
		return
	if not summary_label.text.contains("今日收入：20"):
		_fail("summary scene", "summary did not show day results")
		scene.queue_free()
		return
	scene.queue_free()

	RestaurantRunState.start_new_run(1)
	RestaurantRunState.record_day({
		"day": 1,
		"max_days": 1,
		"completed_orders": 1,
		"failed_orders": 0,
		"queue_lost_customers": 0,
		"money_today": 10,
		"score_today": 10,
		"review_text": "评价：还能再稳一点。"
	})

	var final_scene: Node = scene_resource.instantiate()
	get_root().add_child(final_scene)
	await process_frame
	var final_continue: Button = final_scene.get("continue_button") as Button
	if final_continue == null or final_continue.text != "完成本轮，返回主页":
		_fail("summary scene", "complete run should return home")
		final_scene.queue_free()
		return

	final_scene.queue_free()
	_pass("summary scene")


func _check_staple_timing() -> void:
	var bowl_scene: PackedScene = load("res://scenes/gameplay/restaurant/order_bowl.tscn")
	if bowl_scene == null:
		_fail("staple timing", "order bowl scene could not be loaded")
		return

	var bowl: OrderBowl = bowl_scene.instantiate() as OrderBowl
	get_root().add_child(bowl)
	bowl.setup_order(99, {"spinach": 1}, "noodle", "hot", "takeout", 0)
	bowl.status = OrderBowl.STATUS_COOKING

	if bowl.staple_state != OrderBowl.STAPLE_RAW:
		_fail("staple timing", "new staple should start raw")
		return

	bowl.update_cooking(7.2)
	if bowl.staple_state != OrderBowl.STAPLE_RAW:
		_fail("staple timing", "staple should still be raw before the cooking time")
		return

	bowl.update_cooking(1.0)
	if bowl.status != OrderBowl.STATUS_COOKED or bowl.staple_state != OrderBowl.STAPLE_PERFECT:
		_fail("staple timing", "staple should be cooked after eight seconds")
		return

	bowl.update_cooking(6.1)
	if not bowl.is_overcooked():
		_fail("staple timing", "staple should overcook after the ready window")
		return

	bowl.queue_free()
	_pass("staple timing")


func _pass(step_name: String) -> void:
	print("Restaurant smoke step passed: %s" % step_name)


func _fail(step_name: String, reason: String) -> void:
	failures.append("%s: %s" % [step_name, reason])
	push_error("Restaurant smoke failed at %s: %s" % [step_name, reason])


func _finish() -> void:
	if failures.is_empty():
		print("Restaurant smoke check passed.")
		quit(0)
		return

	for failure in failures:
		print("Restaurant smoke failure: ", failure)
	quit(1)
