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
	manager.held_bowl = takeout_bowl
	manager.interact_sauce_station()
	manager.interact_packing_area()
	manager.interact_takeout_pickup()
	if manager.held_bowl == null:
		_fail("delivery paths", "takeout should not complete at pickup area")
		scene.queue_free()
		return
	manager.interact_counter()
	if manager.held_bowl != null or int(manager.completed_orders) != 1:
		_fail("delivery paths", "packed takeout should complete at counter")
		scene.queue_free()
		return

	var dine_bowl: OrderBowl = OrderBowl.new()
	scene.add_child(dine_bowl)
	dine_bowl.setup_order(502, {"spinach": 1}, "noodle", "hot", "dine_in", 2)
	dine_bowl.status = OrderBowl.STATUS_COOKED
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
	manager.interact_waiting_order_area()
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
	if not takeout_text.contains("收银台"):
		_fail("order card destination", "takeout card should show counter destination")
		scene.queue_free()
		return
	if not takeout_text.contains("#401") or not takeout_text.contains("100%"):
		_fail("order card destination", "takeout card should keep id and patience")
		scene.queue_free()
		return

	var dine_bowl: OrderBowl = OrderBowl.new()
	dine_bowl.setup_order(402, {"spinach": 1}, "noodle", "hot", "dine_in", 2)
	var dine_text: String = manager._get_order_card_text(dine_bowl)
	if not dine_text.contains("堂食桌2"):
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
	ui.update_hand_state("拿着 #001")
	if bool(hand_label.visible):
		_fail("hud layout", "hand label should stay hidden in the simplified HUD")
		ui.queue_free()
		return
	if not hand_label.text.contains("#001"):
		_fail("hud layout", "hidden hand label should keep text for compatibility")
		ui.queue_free()
		return

	ui.show_toast("已打烊：不会再来新顾客", 1.8)
	if not bool(toast_label.visible) or not toast_label.text.contains("已打烊"):
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
