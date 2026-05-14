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

	await _check_overcooked_trash_rule()
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

	scene.free()
	_pass("scene load")


func _check_order_loop() -> void:
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

	scene.queue_free()
	_pass("order loop")


func _check_overcooked_trash_rule() -> void:
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
	manager.interact_waiting_order_area()
	manager.interact_cooker(manager.cooker_1)
	if manager.cooker_1.active_bowl == null:
		_fail("overcooked trash", "order did not enter cooker")
		scene.queue_free()
		return

	manager.cooker_1.active_bowl.update_cooking(7.2)
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

	var bowl_scene: PackedScene = load("res://scenes/gameplay/restaurant/order_bowl.tscn")
	var bowl_1: OrderBowl = bowl_scene.instantiate() as OrderBowl
	var bowl_2: OrderBowl = bowl_scene.instantiate() as OrderBowl
	bowl_1.setup_order(301, {"spinach": 1}, "noodle", "hot", "takeout", 0)
	bowl_2.setup_order(302, {"spinach": 1}, "noodle", "hot", "takeout", 0)
	manager.cooker_1.add_bowl(bowl_1)
	manager.cooker_2.add_bowl(bowl_2)
	manager.cooker_1.active_bowl.update_cooking(7.2)
	manager.cooker_2.active_bowl.update_cooking(7.2)
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

	bowl.update_cooking(3.2)
	if bowl.staple_state != OrderBowl.STAPLE_RAW:
		_fail("staple timing", "staple should still be raw before the cooking time")
		return

	bowl.update_cooking(1.0)
	if bowl.status != OrderBowl.STATUS_COOKED or bowl.staple_state != OrderBowl.STAPLE_PERFECT:
		_fail("staple timing", "staple should be cooked after four seconds")
		return

	bowl.update_cooking(3.1)
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
