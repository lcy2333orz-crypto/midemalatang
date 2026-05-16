extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_scene_loads()
	if not failures.is_empty():
		_finish()
		return

	await _check_tutorial_controller()
	if not failures.is_empty():
		_finish()
		return

	_check_input_mappings()
	if not failures.is_empty():
		_finish()
		return

	await _check_interaction_prompts()
	if not failures.is_empty():
		_finish()
		return

	await _check_sauce_action_buttons()
	if not failures.is_empty():
		_finish()
		return

	await _check_chili_station_actions()
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

	await _check_quality_penalty_delivery_rules()
	if not failures.is_empty():
		_finish()
		return

	await _check_takeout_bad_order_cleanup()
	if not failures.is_empty():
		_finish()
		return

	await _check_order_timing_score()
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

	await _check_pots_spawn_on_stoves()
	if not failures.is_empty():
		_finish()
		return

	await _check_take_and_place_pot()
	if not failures.is_empty():
		_finish()
		return

	await _check_pot_heats_only_on_stove()
	if not failures.is_empty():
		_finish()
		return

	await _check_scoop_from_pot()
	if not failures.is_empty():
		_finish()
		return

	await _check_add_held_order_bowl_to_table_pot()
	if not failures.is_empty():
		_finish()
		return

	await _check_add_table_order_bowl_to_held_pot()
	if not failures.is_empty():
		_finish()
		return

	await _check_cannot_add_order_to_pot_without_staple()
	if not failures.is_empty():
		_finish()
		return

	await _check_cannot_add_order_to_occupied_pot()
	if not failures.is_empty():
		_finish()
		return

	await _check_empty_bowl_not_discarded_while_pot_has_content()
	if not failures.is_empty():
		_finish()
		return

	await _check_empty_pot_and_empty_bowl_do_not_block_day_end()
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

	await _check_visible_text_is_chinese()
	if not failures.is_empty():
		_finish()
		return

	await _check_placeholder_interactions_do_not_mutate()
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
		"RestaurantGameManager",
		"TutorialController"
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
	_assert_node_position(scene, "Stations/DiningTables/DiningTable1", _grid(9, 4), "grid table 1")
	_assert_node_position(scene, "Stations/DiningTables/DiningTable2", _grid(9, 6), "grid table 2")
	_assert_small_shared_interaction_shape(scene)
	_assert_removed_station_interaction_areas(scene)
	_assert_required_interaction_areas(scene)
	_assert_greybox_labels(scene)
	_assert_independent_cell_bodies(scene)
	_assert_removed_duplicate_cells(scene)
	_assert_character_scale(scene)
	_assert_single_highlight(scene)

	scene.free()
	_pass("scene load")


func _check_tutorial_controller() -> void:
	var tutorial_script: Script = load("res://scenes/gameplay/restaurant/tutorial_controller.gd") as Script
	if tutorial_script == null:
		_fail("tutorial controller", "tutorial_controller.gd could not be loaded")
		return

	var direct_controller: TutorialController = TutorialController.new()
	get_root().add_child(direct_controller)
	await process_frame
	if direct_controller.steps.is_empty():
		_fail("tutorial controller", "direct controller did not build steps")
		direct_controller.queue_free()
		return
	for step_id in ["second_intro", "second_counter", "second_pot", "second_clear_overcook", "second_refill_prepare", "second_refill_pick_bowl", "second_refill", "second_chili", "second_deliver", "third_intro", "third_counter", "third_pack", "third_bag", "third_takeout_table", "third_done"]:
		if not _tutorial_has_step_id(direct_controller, step_id):
			_fail("tutorial controller", "missing tutorial step %s" % step_id)
			direct_controller.queue_free()
			return
	direct_controller.queue_free()

	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = scene.get_node_or_null("RestaurantGameManager") as RestaurantGameManager
	var ui: RestaurantUI = scene.get_node_or_null("UI") as RestaurantUI
	var controller: TutorialController = scene.get_node_or_null("TutorialController") as TutorialController
	if manager == null or ui == null or controller == null:
		_fail("tutorial controller", "manager, ui, or tutorial controller was not found")
		scene.queue_free()
		return
	if manager.tutorial_controller != controller:
		_fail("tutorial controller", "manager did not connect to tutorial controller")
		scene.queue_free()
		return
	if int(manager.spawn_count) != 0 or get_nodes_in_group("restaurant_customers").size() != 0:
		_fail("tutorial controller", "tutorial should not auto-spawn customers on scene start")
		scene.queue_free()
		return

	ui.show_tutorial_text("欢迎来到小猫麻辣烫连锁店培训！")
	var tutorial_label: Label = ui.get("tutorial_label") as Label
	var tutorial_panel: Panel = ui.get("tutorial_panel") as Panel
	if tutorial_label == null or tutorial_panel == null or not bool(tutorial_panel.visible):
		_fail("tutorial controller", "tutorial text widgets were not shown")
		scene.queue_free()
		return
	if not tutorial_label.text.contains("欢迎来到小猫麻辣烫连锁店培训"):
		_fail("tutorial controller", "tutorial label did not keep Chinese text")
		scene.queue_free()
		return

	var time_before: float = float(manager.day_time_remaining)
	var patience_bowl: OrderBowl = OrderBowl.new()
	scene.add_child(patience_bowl)
	patience_bowl.setup_order(929, {"spinach": 1}, "noodle", "mild", "dine_in", 1, 0)
	manager._hold_bowl(patience_bowl)
	var patience_before: float = float(patience_bowl.order_patience_current)
	manager._process(12.0)
	if not is_equal_approx(float(manager.day_time_remaining), time_before):
		_fail("tutorial controller", "tutorial pause should stop day timer")
		scene.queue_free()
		return
	if not is_equal_approx(float(patience_bowl.order_patience_current), patience_before):
		_fail("tutorial controller", "tutorial pause should stop order patience")
		scene.queue_free()
		return
	var time_label: Label = ui.get("time_label") as Label
	if time_label == null or time_label.text != "教学中":
		_fail("tutorial controller", "tutorial pause should show 教学中")
		scene.queue_free()
		return
	manager.held_bowl = null
	patience_bowl.queue_free()

	controller.current_step_index = _tutorial_step_index(controller, "wait_counter_order")
	controller.enabled = true
	controller.finished = false
	controller._show_current_step()
	await process_frame
	if int(manager.spawn_count) != 1:
		_fail("tutorial controller", "wait_counter_order should spawn the first tutorial customer")
		scene.queue_free()
		return
	manager._process(999.0)
	if int(manager.spawn_count) != 1:
		_fail("tutorial controller", "tutorial should not auto-spawn extra customers over time")
		scene.queue_free()
		return

	var fake_counter_bowl: OrderBowl = OrderBowl.new()
	scene.add_child(fake_counter_bowl)
	fake_counter_bowl.setup_order(928, {"spinach": 1}, "glass_noodle", "mild", "dine_in", 1, 0)
	controller.enabled = true
	controller.finished = false
	controller.notify_event("counter_order_created", {"bowl": fake_counter_bowl})
	if int(controller.current_step_index) != _tutorial_step_index(controller, "add_staple"):
		_fail("tutorial controller", "counter_order_created did not advance tutorial")
		scene.queue_free()
		return

	for customer_node in get_nodes_in_group("restaurant_customers"):
		var customer: Node = customer_node as Node
		if customer != null and is_instance_valid(customer):
			customer.queue_free()
	manager.queued_customers.clear()
	await process_frame
	var spawn_before_second_intro: int = int(manager.spawn_count)
	controller.current_step_index = _tutorial_step_index(controller, "second_intro")
	controller._show_current_step()
	if int(manager.spawn_count) != spawn_before_second_intro:
		_fail("tutorial controller", "second_intro should not spawn the second customer")
		scene.queue_free()
		return
	controller.current_step_index = _tutorial_step_index(controller, "second_counter")
	controller._show_current_step()
	await process_frame
	if int(manager.spawn_count) != spawn_before_second_intro + 1:
		_fail("tutorial controller", "second_counter should spawn the second tutorial customer")
		scene.queue_free()
		return

	var second_pot_index: int = _tutorial_step_index(controller, "second_pot")
	if second_pot_index < 0:
		_fail("tutorial controller", "second_pot step was not found")
		scene.queue_free()
		return
	var forced_bowl: OrderBowl = OrderBowl.new()
	scene.add_child(forced_bowl)
	forced_bowl.setup_order(930, {"spinach": 1}, "noodle", "mild", "dine_in", 2, 1)
	controller.tutorial_order_index = 2
	controller.current_step_index = second_pot_index
	controller.enabled = true
	controller.finished = false
	controller.forced_overcook_order_id = 0
	controller.waiting_for_refill_order_id = 0
	controller.notify_event("bowl_in_pot", {"bowl": forced_bowl})
	if not forced_bowl.is_overcooked() or int(controller.forced_overcook_order_id) != 930:
		_fail("tutorial controller", "second order did not force overcook")
		scene.queue_free()
		return
	forced_bowl.refill_from_ticket()
	controller.current_step_index = _tutorial_step_index(controller, "second_recook")
	controller.notify_event("bowl_in_pot", {"bowl": forced_bowl})
	if forced_bowl.is_overcooked():
		_fail("tutorial controller", "second order forced overcook more than once")
		scene.queue_free()
		return

	var tutorial_pot: CookingPot = CookingPot.new()
	scene.add_child(tutorial_pot)
	var tutorial_overcooked_bowl: OrderBowl = OrderBowl.new()
	tutorial_overcooked_bowl.setup_order(931, {"spinach": 1}, "noodle", "mild", "dine_in", 2, 1)
	tutorial_overcooked_bowl.add_required_staple()
	tutorial_pot.add_order_bowl(tutorial_overcooked_bowl)
	tutorial_overcooked_bowl.force_overcooked_for_tutorial()
	var original_holder: OrderBowl = OrderBowl.new()
	scene.add_child(original_holder)
	original_holder.setup_order(931, {"spinach": 1}, "noodle", "mild", "dine_in", 2, 1)
	original_holder.set_empty_holder_visual()
	var waiting_customer: Node = Node.new()
	scene.add_child(waiting_customer)
	manager.waiting_customers_by_order_id[931] = waiting_customer
	controller.forced_overcook_order_id = 931
	controller.waiting_for_refill_order_id = 931
	if manager.cooker_1.active_pot != null:
		var initial_pot: CookingPot = manager.cooker_1.take_pot()
		if initial_pot != null:
			initial_pot.queue_free()
	manager.cooker_1.place_pot(tutorial_pot)
	manager.held_bowl = original_holder
	manager.held_pot = null
	controller.current_step_index = _tutorial_step_index(controller, "second_overcooked")
	if not manager._try_take_overcooked_pot_from_cooker(manager.cooker_1):
		_fail("tutorial controller", "player should be able to take tutorial overcooked pot while holding original empty bowl")
		scene.queue_free()
		return
	if manager.held_pot != tutorial_pot or manager.held_bowl != null:
		_fail("tutorial controller", "taking overcooked pot should leave pot in hand and remove holder from hand")
		scene.queue_free()
		return
	if not manager.tutorial_refill_holder_by_order_id.has(931) or manager.tutorial_refill_holder_by_order_id[931] != original_holder:
		_fail("tutorial controller", "original holder should be tracked for tutorial refill")
		scene.queue_free()
		return
	var original_holder_slot_id: String = _find_surface_slot_holding_bowl(manager, original_holder)
	if original_holder_slot_id == "":
		_fail("tutorial controller", "original holder should be placed on a surface slot before clearing overcook")
		scene.queue_free()
		return
	if original_holder.needs_refill:
		_fail("tutorial controller", "original holder should not be marked refill until overcook is cleared")
		scene.queue_free()
		return
	var failed_before_tutorial_clear: int = int(manager.failed_orders)
	manager.interact_trash_bin()
	if int(manager.failed_orders) != failed_before_tutorial_clear:
		_fail("tutorial controller", "tutorial forced overcook should not add failure")
		scene.queue_free()
		return
	if not manager.waiting_customers_by_order_id.has(931):
		_fail("tutorial controller", "tutorial forced overcook should keep waiting customer")
		scene.queue_free()
		return
	if manager.held_pot == null or not manager.held_pot.is_empty() or manager.held_bowl != null:
		_fail("tutorial controller", "tutorial forced overcook should leave empty pot in hand")
		scene.queue_free()
		return
	if not original_holder.needs_refill:
		_fail("tutorial controller", "tutorial forced overcook should mark original holder as refill bowl")
		scene.queue_free()
		return
	if _find_surface_slot_holding_bowl(manager, original_holder) != original_holder_slot_id:
		_fail("tutorial controller", "tutorial forced overcook should reuse the same original holder on the same surface slot")
		scene.queue_free()
		return
	if tutorial_overcooked_bowl != null and is_instance_valid(tutorial_overcooked_bowl) and not tutorial_overcooked_bowl.is_queued_for_deletion():
		_fail("tutorial controller", "tutorial forced overcook should clear cooked content instead of turning it into refill bowl")
		scene.queue_free()
		return
	if _count_empty_holders_for_order(manager, 931) != 1:
		_fail("tutorial controller", "tutorial forced overcook should leave exactly one holder for the order")
		scene.queue_free()
		return

	controller.current_step_index = _tutorial_step_index(controller, "second_refill_prepare")
	manager.interact_cooker(manager.cooker_1)
	if manager.held_pot != null or manager.cooker_1.active_pot == null:
		_fail("tutorial controller", "player should be able to place tutorial empty pot back on cooker")
		scene.queue_free()
		return
	if int(controller.current_step_index) != _tutorial_step_index(controller, "second_refill_pick_bowl"):
		_fail("tutorial controller", "pot_placed_on_cooker did not advance tutorial")
		scene.queue_free()
		return

	manager.interact_surface_slot(original_holder_slot_id)
	if manager.held_bowl != original_holder or not manager.held_bowl.needs_refill:
		_fail("tutorial controller", "player should be able to pick up refill bowl from surface slot")
		scene.queue_free()
		return
	if int(controller.current_step_index) != _tutorial_step_index(controller, "second_refill"):
		_fail("tutorial controller", "refill_bowl_picked_up did not advance tutorial")
		scene.queue_free()
		return

	controller.current_step_index = _tutorial_step_index(controller, "second_refill")
	manager.interact_ingredient_display()
	if manager.held_bowl == null or manager.held_bowl.needs_refill or manager.held_bowl.is_empty_holder or manager.held_bowl.status != OrderBowl.STATUS_WAITING or bool(manager.held_bowl.staple_added) or manager.held_bowl.actual_staple_type != "none":
		_fail("tutorial controller", "tutorial refill did not restore bowl to waiting without staple")
		scene.queue_free()
		return
	if manager.tutorial_refill_holder_by_order_id.has(931):
		_fail("tutorial controller", "tutorial refill tracking should clear after refill")
		scene.queue_free()
		return

	var missing_holder_pot: CookingPot = CookingPot.new()
	scene.add_child(missing_holder_pot)
	var missing_holder_bowl: OrderBowl = OrderBowl.new()
	missing_holder_bowl.setup_order(934, {"spinach": 1}, "noodle", "mild", "dine_in", 2, 1)
	missing_holder_bowl.add_required_staple()
	missing_holder_pot.add_order_bowl(missing_holder_bowl)
	missing_holder_bowl.force_overcooked_for_tutorial()
	controller.forced_overcook_order_id = 934
	controller.waiting_for_refill_order_id = 934
	manager.held_bowl = null
	manager.held_pot = missing_holder_pot
	manager.interact_trash_bin()
	if missing_holder_bowl != null and is_instance_valid(missing_holder_bowl) and not missing_holder_bowl.is_queued_for_deletion():
		_fail("tutorial controller", "missing-holder tutorial overcook should clear cooked content")
		scene.queue_free()
		return
	if _count_empty_holders_for_order(manager, 934) != 0:
		_fail("tutorial controller", "missing-holder tutorial overcook should not create a refill holder")
		scene.queue_free()
		return

	var normal_pot: CookingPot = CookingPot.new()
	scene.add_child(normal_pot)
	var normal_overcooked_bowl: OrderBowl = OrderBowl.new()
	normal_overcooked_bowl.setup_order(932, {"spinach": 1}, "noodle", "mild", "dine_in", 2, 1)
	normal_overcooked_bowl.add_required_staple()
	normal_pot.add_order_bowl(normal_overcooked_bowl)
	normal_overcooked_bowl.force_overcooked_for_tutorial()
	controller.waiting_for_refill_order_id = 0
	manager.held_bowl = null
	manager.held_pot = normal_pot
	var failed_before_normal_clear: int = int(manager.failed_orders)
	manager.interact_trash_bin()
	if int(manager.failed_orders) != failed_before_normal_clear + 1:
		_fail("tutorial controller", "normal overcook should still add failure")
		scene.queue_free()
		return

	for customer_node in get_nodes_in_group("restaurant_customers"):
		var cleanup_customer: Node = customer_node as Node
		if cleanup_customer != null and is_instance_valid(cleanup_customer):
			cleanup_customer.queue_free()
	manager.queued_customers.clear()
	manager.waiting_customers_by_order_id.clear()
	manager.held_bowl = null
	manager.held_pot = null
	await process_frame
	var spawn_before_third_intro: int = int(manager.spawn_count)
	var stale_customer_scene: PackedScene = load("res://scenes/gameplay/restaurant/restaurant_customer.tscn")
	var stale_customer: RestaurantCustomer = stale_customer_scene.instantiate() as RestaurantCustomer
	scene.add_child(stale_customer)
	controller.current_step_index = _tutorial_step_index(controller, "third_intro")
	controller._show_current_step()
	if int(manager.spawn_count) != spawn_before_third_intro:
		_fail("tutorial controller", "third_intro should not spawn the third customer")
		scene.queue_free()
		return
	controller.current_step_index = _tutorial_step_index(controller, "third_counter")
	controller._show_current_step()
	await process_frame
	if int(manager.spawn_count) != spawn_before_third_intro + 1 or int(controller.tutorial_order_index) != 3:
		_fail("tutorial controller", "third_counter should spawn one third tutorial customer")
		scene.queue_free()
		return
	if str(manager.next_tutorial_order.get("service_mode", "")) != "takeout" or str(manager.next_tutorial_order.get("staple_type", "")) != "glass_noodle":
		_fail("tutorial controller", "third_counter should prepare takeout tutorial order override")
		scene.queue_free()
		return

	var takeout_bowl: OrderBowl = OrderBowl.new()
	scene.add_child(takeout_bowl)
	takeout_bowl.setup_order(933, {"spinach": 1}, "glass_noodle", "mild", "takeout", 0, 0)
	takeout_bowl.status = OrderBowl.STATUS_COOKED
	for sauce_id in takeout_bowl.required_mixed_sauces:
		takeout_bowl.add_mixed_sauce_once(str(sauce_id))
	controller.tutorial_order_index = 3
	controller.current_step_index = _tutorial_step_index(controller, "third_pack")
	manager.held_pot = null
	manager._hold_bowl(takeout_bowl)
	manager.interact_packing_area()
	if takeout_bowl.status != OrderBowl.STATUS_SEALED or int(controller.current_step_index) != _tutorial_step_index(controller, "third_bag"):
		_fail("tutorial controller", "takeout_order_sealed should seal bowl and advance tutorial")
		scene.queue_free()
		return
	manager.interact_packing_bag_area()
	if takeout_bowl.status != OrderBowl.STATUS_PACKED or int(controller.current_step_index) != _tutorial_step_index(controller, "third_takeout_table"):
		_fail("tutorial controller", "takeout_order_packed should pack bowl and advance tutorial")
		scene.queue_free()
		return
	manager.interact_surface_slot("TakeoutPickupSlot1")
	if int(controller.current_step_index) != _tutorial_step_index(controller, "third_done"):
		_fail("tutorial controller", "takeout completion should advance tutorial")
		scene.queue_free()
		return
	scene.queue_free()
	await process_frame

	RestaurantRunState.start_new_run(3)
	var disabled_scene: Node = scene_resource.instantiate()
	var disabled_controller: TutorialController = disabled_scene.get_node_or_null("TutorialController") as TutorialController
	if disabled_controller != null:
		disabled_controller.tutorial_enabled = false
	get_root().add_child(disabled_scene)
	await process_frame
	await process_frame

	var disabled_manager: RestaurantGameManager = disabled_scene.get_node_or_null("RestaurantGameManager") as RestaurantGameManager
	var connected_disabled_controller: TutorialController = disabled_scene.get_node_or_null("TutorialController") as TutorialController
	if disabled_manager == null or connected_disabled_controller == null:
		_fail("tutorial controller", "disabled tutorial scene did not load")
		disabled_scene.queue_free()
		return
	if bool(connected_disabled_controller.enabled):
		_fail("tutorial controller", "disabled tutorial should not enable")
		disabled_scene.queue_free()
		return
	connected_disabled_controller.current_step_index = 3
	connected_disabled_controller.notify_event("counter_order_created", {})
	if int(connected_disabled_controller.current_step_index) != 3:
		_fail("tutorial controller", "disabled tutorial should not advance")
		disabled_scene.queue_free()
		return
	var completed: bool = await disabled_manager.force_complete_one_order_for_smoke()
	if not completed:
		_fail("tutorial controller", "disabled tutorial should not block order completion")
		disabled_scene.queue_free()
		return

	disabled_scene.queue_free()
	_pass("tutorial controller")


func _tutorial_has_step_id(controller: TutorialController, step_id: String) -> bool:
	return _tutorial_step_index(controller, step_id) >= 0


func _tutorial_step_index(controller: TutorialController, step_id: String) -> int:
	if controller == null:
		return -1
	for i in range(controller.steps.size()):
		var step: Dictionary = controller.steps[i]
		if str(step.get("id", "")) == step_id:
			return i
	return -1


func _find_surface_slot_holding_bowl(manager: RestaurantGameManager, bowl: OrderBowl) -> String:
	if manager == null or bowl == null:
		return ""
	for slot_value in manager.surface_slots_by_id.values():
		var slot: SurfaceSlot = slot_value as SurfaceSlot
		if slot != null and slot.get_stored_bowl() == bowl:
			return slot.slot_id
	return ""


func _count_empty_holders_for_order(manager: RestaurantGameManager, order_id: int) -> int:
	if manager == null:
		return 0
	var seen: Dictionary = {}
	var count: int = 0
	var candidates: Array[OrderBowl] = []
	if manager.held_bowl != null:
		candidates.append(manager.held_bowl)
	for slot_value in manager.surface_slots_by_id.values():
		var slot: SurfaceSlot = slot_value as SurfaceSlot
		if slot != null:
			var slot_bowl: OrderBowl = slot.get_stored_bowl()
			if slot_bowl != null:
				candidates.append(slot_bowl)
	for waiting_bowl in manager.waiting_area.bowls:
		var waiting_order: OrderBowl = waiting_bowl as OrderBowl
		if waiting_order != null:
			candidates.append(waiting_order)
	if manager.bowls_node != null:
		for child in manager.bowls_node.get_children():
			var world_bowl: OrderBowl = child as OrderBowl
			if world_bowl != null:
				candidates.append(world_bowl)
	for bowl in candidates:
		if bowl == null or not is_instance_valid(bowl) or bowl.is_queued_for_deletion():
			continue
		var instance_id: int = bowl.get_instance_id()
		if seen.has(instance_id):
			continue
		seen[instance_id] = true
		if bowl.order_id == order_id and bowl.is_empty_holder:
			count += 1
	return count


func _check_input_mappings() -> void:
	var key_checks: Dictionary = {
		"ui_left": [KEY_A, KEY_LEFT],
		"ui_right": [KEY_D, KEY_RIGHT],
		"ui_up": [KEY_W, KEY_UP],
		"ui_down": [KEY_S, KEY_DOWN],
		"interact": [KEY_H],
		"sauce_x": [KEY_H],
		"sauce_y": [KEY_J],
		"sauce_a": [KEY_K],
		"sauce_b": [KEY_L],
	}
	for action_name in key_checks:
		if not InputMap.has_action(action_name):
			_fail("input mappings", "missing action %s" % action_name)
			continue
		for keycode in key_checks[action_name]:
			if not _action_has_key(action_name, int(keycode)):
				_fail("input mappings", "%s missing key %s" % [action_name, keycode])

	if _action_has_key("interact", KEY_E):
		_fail("input mappings", "interact should not still use E")

	var motion_checks: Array[Array] = [
		["ui_left", JOY_AXIS_LEFT_X, -1.0],
		["ui_right", JOY_AXIS_LEFT_X, 1.0],
		["ui_up", JOY_AXIS_LEFT_Y, -1.0],
		["ui_down", JOY_AXIS_LEFT_Y, 1.0],
	]
	for check in motion_checks:
		if not _action_has_joy_motion(str(check[0]), int(check[1]), float(check[2])):
			_fail("input mappings", "%s missing left stick motion" % check[0])

	var button_checks: Dictionary = {
		"interact": JOY_BUTTON_X,
		"sauce_x": JOY_BUTTON_X,
		"sauce_y": JOY_BUTTON_Y,
		"sauce_a": JOY_BUTTON_A,
		"sauce_b": JOY_BUTTON_B,
	}
	for action_name in button_checks:
		if not _action_has_joy_button(action_name, int(button_checks[action_name])):
			_fail("input mappings", "%s missing joy button %s" % [action_name, button_checks[action_name]])

	if failures.is_empty():
		_pass("input mappings")


func _check_interaction_prompts() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame

	var counter_area: RestaurantStationArea = scene.get_node_or_null("Stations/Counter/InteractionArea") as RestaurantStationArea
	var sauce_area: RestaurantStationArea = scene.get_node_or_null("Stations/SauceStation/InteractionArea") as RestaurantStationArea
	var mixed_area: RestaurantStationArea = scene.get_node_or_null("LockedPlaceholders/SauceStationMixed/InteractionArea") as RestaurantStationArea
	if counter_area == null or sauce_area == null or mixed_area == null:
		_fail("interaction prompts", "missing prompt station area")
		scene.queue_free()
		return

	var counter_prompt: String = counter_area.get_interaction_prompt()
	var sauce_prompt: String = sauce_area.get_interaction_prompt()
	var mixed_prompt: String = mixed_area.get_interaction_prompt()
	if not counter_prompt.contains("[H]") or counter_prompt.contains("[E]"):
		_fail("interaction prompts", "normal prompt should use [H], got %s" % counter_prompt)
		scene.queue_free()
		return
	if not sauce_prompt.contains("[H]") or not sauce_prompt.contains("辣椒") or sauce_prompt.contains("H/J/K/L") or sauce_prompt.contains("[E]"):
		_fail("interaction prompts", "chili prompt should show [H] 辣椒, got %s" % sauce_prompt)
		scene.queue_free()
		return
	if not mixed_prompt.contains("H/J/K/L") or not mixed_prompt.contains("小料桶") or mixed_prompt.contains("[E]"):
		_fail("interaction prompts", "mixed sauce prompt should show H/J/K/L 小料桶, got %s" % mixed_prompt)
		scene.queue_free()
		return

	scene.queue_free()
	_pass("interaction prompts")


func _check_sauce_action_buttons() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("sauce actions", "restaurant manager was not found")
		scene.queue_free()
		return

	var bowl: OrderBowl = OrderBowl.new()
	scene.add_child(bowl)
	bowl.setup_order(901, {"spinach": 1}, "none", "mild", "dine_in", 1)
	bowl.status = OrderBowl.STATUS_COOKED
	manager._hold_bowl(bowl)

	var expected: Dictionary = {
		"sauce_x": "garlic_water",
		"sauce_y": "sesame_paste",
		"sauce_a": "vinegar",
		"sauce_b": "sugar",
	}
	for action_name in expected:
		var sauce_id: String = expected[action_name]
		manager.interact_with_station_action("SauceStationMixed", action_name)
		if not bowl.sauces.has(sauce_id):
			_fail("sauce actions", "%s did not add %s" % [action_name, sauce_id])
			scene.queue_free()
			return

	var sauce_count: int = bowl.sauces.size()
	manager.interact_with_station_action("SauceStationMixed", "sauce_x")
	if bowl.sauces.size() != sauce_count:
		_fail("sauce actions", "duplicate sauce should not be added")
		scene.queue_free()
		return
	if not bowl.has_all_required_mixed_sauces():
		_fail("sauce actions", "bowl should have all required mixed sauces")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("sauce actions")


func _check_chili_station_actions() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("chili actions", "restaurant manager was not found")
		scene.queue_free()
		return

	var no_chili_bowl: OrderBowl = OrderBowl.new()
	scene.add_child(no_chili_bowl)
	no_chili_bowl.setup_order(911, {"spinach": 1}, "none", "none", "dine_in", 1, 0)
	no_chili_bowl.status = OrderBowl.STATUS_COOKED
	manager._hold_bowl(no_chili_bowl)
	manager.interact_with_station_action("SauceStation", "sauce_x")
	if no_chili_bowl.added_chili_count != 0:
		_fail("chili actions", "zero-chili order should not add chili")
		scene.queue_free()
		return

	var chili_bowl: OrderBowl = OrderBowl.new()
	scene.add_child(chili_bowl)
	chili_bowl.setup_order(912, {"spinach": 1}, "none", "medium", "dine_in", 1, 2)
	chili_bowl.status = OrderBowl.STATUS_COOKED
	manager._hold_bowl(chili_bowl)
	manager.interact_with_station_action("SauceStation", "sauce_x")
	manager.interact_with_station_action("SauceStation", "sauce_x")
	if chili_bowl.added_chili_count != 2:
		_fail("chili actions", "two chili actions should add exactly two")
		scene.queue_free()
		return
	manager.interact_with_station_action("SauceStation", "sauce_x")
	if chili_bowl.added_chili_count != 2:
		_fail("chili actions", "third chili action should not exceed required count")
		scene.queue_free()
		return
	for action_name in ["sauce_y", "sauce_a", "sauce_b"]:
		manager.interact_with_station_action("SauceStation", action_name)
		if chili_bowl.added_chili_count != 2:
			_fail("chili actions", "%s should not add chili" % action_name)
			scene.queue_free()
			return

	scene.queue_free()
	_pass("chili actions")


func _assert_greybox_labels(scene: Node) -> void:
	var expected_labels: Dictionary = {
		"GridVisual/GridLineV0": "",
		"GridVisual/GridLineV15": "",
		"GridVisual/GridLineH0": "",
		"GridVisual/GridLineH9": "",
		"PlayerSpawns/PlayerSpawn1/Label": "1P 出生",
		"PlayerSpawns/PlayerSpawn2/Label": "2P 出生",
		"PlayerSpawns/PlayerSpawn3/Label": "3P 出生",
		"PlayerSpawns/PlayerSpawn4/Label": "4P 出生",
		"LockedPlaceholders/DoorCell1/Label": "门",
		"LockedPlaceholders/DoorCell2/Label": "门",
		"LockedPlaceholders/IngredientDisplay2/Label": "选菜2",
		"LockedPlaceholders/IngredientDisplay3/Label": "选菜3",
		"LockedPlaceholders/IngredientDisplay4Locked/Label": "选菜锁定",
		"LockedPlaceholders/DrinkFridge2Locked/Label": "饮料锁定",
		"LockedPlaceholders/Cooker3Locked/Label": "锅位锁定",
		"LockedPlaceholders/SauceStationMixed/Label": "小料桶",
		"LockedPlaceholders/PackingBagArea/Label": "袋子区",
		"SurfaceSlots/TakeoutPickupSlot1/Label": "外带桌1",
		"SurfaceSlots/TakeoutPickupSlot2/Label": "外带桌2",
		"LockedPlaceholders/CustomerTrashBin/Label": "客用垃圾桶",
		"LockedPlaceholders/DrinkStorage/Label": "饮料箱",
		"Stations/IngredientDisplay/Label": "选菜1",
		"Stations/DrinksFridge/Label": "饮料1",
		"Stations/Counter/Label": "收银台",
		"Stations/StapleArea/Label": "主食柜",
		"Stations/CookerStations/CookerStation1/Label": "锅位1",
		"Stations/CookerStations/CookerStation2/Label": "锅位2",
		"Stations/CookerStations/CookerStation1/StatusLabel": "空锅",
		"Stations/CookerStations/CookerStation2/StatusLabel": "空锅",
		"Stations/SauceStation/Label": "辣椒",
		"Stations/PackingArea/Label": "封口机",
		"Stations/TakeoutPickup/Label": "外带桌1",
		"Stations/TrashBin/Label": "厨房垃圾桶",
		"Stations/StorageArea/Label": "冰箱",
		"Stations/DiningTables/DiningTable1/Label": "桌1",
		"Stations/DiningTables/DiningTable2/Label": "桌2",
		"SurfaceSlots/SurfaceSlot_r1c8/Label": "空桌 r1c8",
		"SurfaceSlots/SurfaceSlot_r1c9/Label": "空桌 r1c9",
		"SurfaceSlots/SurfaceSlot_r1c10/Label": "空桌 r1c10",
		"SurfaceSlots/SurfaceSlot_r1c11/Label": "空桌 r1c11",
		"SurfaceSlots/SurfaceSlot_r2c10/Label": "空桌 r2c10",
		"SurfaceSlots/SurfaceSlot_r3c10/Label": "空桌 r3c10",
		"SurfaceSlots/SurfaceSlot_r4c10/Label": "空桌 r4c10",
		"SurfaceSlots/SurfaceSlot_r5c10/Label": "空桌 r5c10",
		"SurfaceSlots/SurfaceSlot_r6c10/Label": "空桌 r6c10",
		"SurfaceSlots/SurfaceSlot_r1c15/Label": "空桌 r1c15",
		"SurfaceSlots/SurfaceSlot_r2c15/Label": "空桌 r2c15",
		"SurfaceSlots/SurfaceSlot_r4c15/Label": "空桌 r4c15",
		"SurfaceSlots/SurfaceSlot_r6c15/Label": "空桌 r6c15",
		"SurfaceSlots/SurfaceSlot_r8c15/Label": "空桌 r8c15",
		"SurfaceSlots/SurfaceSlot_r9c15/Label": "空桌 r9c15",
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
	var old_waiting_visual: CanvasItem = scene.get_node_or_null("Stations/WaitingOrderArea/Visual") as CanvasItem
	var old_waiting_label: CanvasItem = scene.get_node_or_null("Stations/WaitingOrderArea/Label") as CanvasItem
	var old_waiting_area: Area2D = scene.get_node_or_null("Stations/WaitingOrderArea/InteractionArea") as Area2D
	var old_waiting_shape: CollisionShape2D = scene.get_node_or_null("Stations/WaitingOrderArea/InteractionArea/CollisionShape2D") as CollisionShape2D
	var old_waiting_solid_shape: CollisionShape2D = scene.get_node_or_null("Stations/WaitingOrderArea/SolidBody/CollisionShape2D") as CollisionShape2D
	if old_waiting_visual == null or old_waiting_label == null or old_waiting_area == null or old_waiting_shape == null or old_waiting_solid_shape == null:
		_fail("greybox labels", "missing old WaitingOrderArea nodes")
		return
	if old_waiting_visual.visible or old_waiting_label.visible or old_waiting_area.monitoring or not old_waiting_shape.disabled or not old_waiting_solid_shape.disabled:
		_fail("greybox labels", "old WaitingOrderArea should be hidden and non-interactive")


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
		"LockedPlaceholders/CustomerTrashBin",
		"LockedPlaceholders/DrinkStorage",
	]
	for path in placeholders:
		_assert_solid_independent_cell(scene, path, true)


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


func _assert_small_shared_interaction_shape(scene: Node) -> void:
	var normal_shape: CollisionShape2D = scene.get_node_or_null("Stations/CookerStations/CookerStation1/InteractionArea/CollisionShape2D") as CollisionShape2D
	if normal_shape == null:
		_fail("interaction shape", "missing cooker interaction shape")
		return

	var normal_rect: RectangleShape2D = normal_shape.shape as RectangleShape2D
	if normal_rect == null:
		_fail("interaction shape", "normal interaction shape is not RectangleShape2D")
		return
	if normal_rect.size.x > 55.0 or normal_rect.size.y > 55.0:
		_fail("interaction shape", "normal interaction shape too large: %s" % normal_rect.size)

	var normal_paths: Array[String] = [
		"Stations/CookerStations/CookerStation1/InteractionArea/CollisionShape2D",
		"Stations/CookerStations/CookerStation2/InteractionArea/CollisionShape2D",
		"Stations/SauceStation/InteractionArea/CollisionShape2D",
		"Stations/PackingArea/InteractionArea/CollisionShape2D",
		"Stations/TrashBin/InteractionArea/CollisionShape2D",
		"Stations/DiningTables/DiningTable1/InteractionArea/CollisionShape2D",
		"Stations/DiningTables/DiningTable2/InteractionArea/CollisionShape2D",
		"Stations/DiningTables/DiningTable3/InteractionArea/CollisionShape2D",
		"Stations/IngredientDisplay/InteractionArea/CollisionShape2D",
		"Stations/DrinksFridge/InteractionArea/CollisionShape2D",
		"Stations/StorageArea/InteractionArea/CollisionShape2D",
		"LockedPlaceholders/IngredientDisplay2/InteractionArea/CollisionShape2D",
		"LockedPlaceholders/IngredientDisplay3/InteractionArea/CollisionShape2D",
		"LockedPlaceholders/IngredientDisplay4Locked/InteractionArea/CollisionShape2D",
		"LockedPlaceholders/DrinkFridge2Locked/InteractionArea/CollisionShape2D",
		"LockedPlaceholders/Cooker3Locked/InteractionArea/CollisionShape2D",
		"LockedPlaceholders/SauceStationMixed/InteractionArea/CollisionShape2D",
		"LockedPlaceholders/PackingBagArea/InteractionArea/CollisionShape2D",
		"LockedPlaceholders/CustomerTrashBin/InteractionArea/CollisionShape2D",
		"LockedPlaceholders/DrinkStorage/InteractionArea/CollisionShape2D",
	]
	for path in normal_paths:
		var shape_node: CollisionShape2D = scene.get_node_or_null(path) as CollisionShape2D
		if shape_node == null:
			_fail("interaction shape", "missing %s" % path)
			continue
		if shape_node.shape != normal_shape.shape:
			_fail("interaction shape", "%s does not use shared normal shape" % path)

	var surface_shape: CollisionShape2D = scene.get_node_or_null("SurfaceSlots/SurfaceSlot_r1c8/InteractionArea/CollisionShape2D") as CollisionShape2D
	if surface_shape == null:
		_fail("interaction shape", "missing SurfaceSlot_r1c8 interaction shape")
		return
	var surface_rect: RectangleShape2D = surface_shape.shape as RectangleShape2D
	if surface_rect == null:
		_fail("interaction shape", "surface interaction shape is not RectangleShape2D")
		return
	if surface_rect.size.x < 56.0 or surface_rect.size.x > 62.0 or surface_rect.size.y < 56.0 or surface_rect.size.y > 62.0:
		_fail("interaction shape", "surface interaction shape expected about 60x60 but was %s" % surface_rect.size)

	var surface_paths: Array[String] = [
		"SurfaceSlots/SurfaceSlot_r1c8/InteractionArea/CollisionShape2D",
		"SurfaceSlots/SurfaceSlot_r1c9/InteractionArea/CollisionShape2D",
		"SurfaceSlots/SurfaceSlot_r1c10/InteractionArea/CollisionShape2D",
		"SurfaceSlots/SurfaceSlot_r1c11/InteractionArea/CollisionShape2D",
		"SurfaceSlots/SurfaceSlot_r2c10/InteractionArea/CollisionShape2D",
		"SurfaceSlots/SurfaceSlot_r3c10/InteractionArea/CollisionShape2D",
		"SurfaceSlots/SurfaceSlot_r4c10/InteractionArea/CollisionShape2D",
		"SurfaceSlots/SurfaceSlot_r5c10/InteractionArea/CollisionShape2D",
		"SurfaceSlots/SurfaceSlot_r6c10/InteractionArea/CollisionShape2D",
		"SurfaceSlots/SurfaceSlot_r1c15/InteractionArea/CollisionShape2D",
		"SurfaceSlots/SurfaceSlot_r2c15/InteractionArea/CollisionShape2D",
		"SurfaceSlots/SurfaceSlot_r4c15/InteractionArea/CollisionShape2D",
		"SurfaceSlots/SurfaceSlot_r6c15/InteractionArea/CollisionShape2D",
		"SurfaceSlots/SurfaceSlot_r8c15/InteractionArea/CollisionShape2D",
		"SurfaceSlots/SurfaceSlot_r9c15/InteractionArea/CollisionShape2D",
		"SurfaceSlots/TakeoutPickupSlot1/InteractionArea/CollisionShape2D",
		"SurfaceSlots/TakeoutPickupSlot2/InteractionArea/CollisionShape2D",
	]
	for path in surface_paths:
		var shape_node: CollisionShape2D = scene.get_node_or_null(path) as CollisionShape2D
		if shape_node == null:
			_fail("interaction shape", "missing %s" % path)
			continue
		if shape_node.shape != surface_shape.shape:
			_fail("interaction shape", "%s does not use shared surface shape" % path)

	var counter_shape: CollisionShape2D = scene.get_node_or_null("Stations/Counter/InteractionArea/CollisionShape2D") as CollisionShape2D
	var staple_shape: CollisionShape2D = scene.get_node_or_null("Stations/StapleArea/InteractionArea/CollisionShape2D") as CollisionShape2D
	_assert_centered_station_shape(counter_shape, "Counter")
	_assert_centered_station_shape(staple_shape, "StapleArea")


func _assert_centered_station_shape(shape_node: CollisionShape2D, label: String) -> void:
	if shape_node == null:
		_fail("interaction shape", "%s missing centered interaction shape" % label)
		return
	var rect: RectangleShape2D = shape_node.shape as RectangleShape2D
	if rect == null:
		_fail("interaction shape", "%s centered shape is not RectangleShape2D" % label)
		return
	if absf(shape_node.position.x) > 0.1 or absf(shape_node.position.y) > 0.1:
		_fail("interaction shape", "%s centered shape should not be offset: %s" % [label, shape_node.position])
	if rect.size.x < 40.0 or rect.size.x > 52.0 or rect.size.y < 34.0 or rect.size.y > 44.0:
		_fail("interaction shape", "%s centered shape should be about one grid cell: %s" % [label, rect.size])


func _assert_removed_station_interaction_areas(scene: Node) -> void:
	var removed_paths: Array[String] = [
		"Stations/EntranceZone/InteractionArea",
		"Stations/TakeoutPickup/InteractionArea",
	]
	for path in removed_paths:
		if scene.get_node_or_null(path) != null:
			_fail("interaction cleanup", "%s should not exist" % path)


func _assert_required_interaction_areas(scene: Node) -> void:
	var required_paths: Array[String] = [
		"Stations/Counter/InteractionArea",
		"Stations/StapleArea/InteractionArea",
		"Stations/CookerStations/CookerStation1/InteractionArea",
		"Stations/CookerStations/CookerStation2/InteractionArea",
		"Stations/SauceStation/InteractionArea",
		"Stations/PackingArea/InteractionArea",
		"Stations/TrashBin/InteractionArea",
		"Stations/DiningTables/DiningTable1/InteractionArea",
		"Stations/DiningTables/DiningTable2/InteractionArea",
		"Stations/DiningTables/DiningTable3/InteractionArea",
		"Stations/IngredientDisplay/InteractionArea",
		"Stations/DrinksFridge/InteractionArea",
		"Stations/StorageArea/InteractionArea",
		"LockedPlaceholders/IngredientDisplay2/InteractionArea",
		"LockedPlaceholders/IngredientDisplay3/InteractionArea",
		"LockedPlaceholders/IngredientDisplay4Locked/InteractionArea",
		"LockedPlaceholders/DrinkFridge2Locked/InteractionArea",
		"LockedPlaceholders/Cooker3Locked/InteractionArea",
		"LockedPlaceholders/SauceStationMixed/InteractionArea",
		"LockedPlaceholders/PackingBagArea/InteractionArea",
		"LockedPlaceholders/CustomerTrashBin/InteractionArea",
		"LockedPlaceholders/DrinkStorage/InteractionArea",
		"SurfaceSlots/SurfaceSlot_r1c8/InteractionArea",
		"SurfaceSlots/TakeoutPickupSlot1/InteractionArea",
		"SurfaceSlots/TakeoutPickupSlot2/InteractionArea",
	]
	for path in required_paths:
		var area: Area2D = scene.get_node_or_null(path) as Area2D
		if area == null:
			_fail("required interaction", "missing %s" % path)
			continue
		var shape_node: CollisionShape2D = area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node == null:
			_fail("required interaction", "%s missing CollisionShape2D" % path)


func _assert_removed_duplicate_cells(scene: Node) -> void:
	if scene.get_node_or_null("LockedPlaceholders/TakeoutPickupTable2") != null:
		_fail("duplicate cells", "LockedPlaceholders/TakeoutPickupTable2 should not exist")
	if scene.get_node_or_null("Stations/EntranceZone/SolidBody") != null:
		_fail("duplicate cells", "EntranceZone should not have SolidBody")
	if scene.get_node_or_null("LockedPlaceholders/DoorCell1/SolidBody") != null:
		_fail("duplicate cells", "DoorCell1 should not have SolidBody")
	if scene.get_node_or_null("LockedPlaceholders/DoorCell2/SolidBody") != null:
		_fail("duplicate cells", "DoorCell2 should not have SolidBody")


func _assert_single_highlight(scene: Node) -> void:
	var player: Node = scene.get_node_or_null("Characters/Player")
	var counter_area: Area2D = scene.get_node_or_null("Stations/Counter/InteractionArea") as Area2D
	var staple_area: Area2D = scene.get_node_or_null("Stations/StapleArea/InteractionArea") as Area2D
	var counter_visual: Polygon2D = scene.get_node_or_null("Stations/Counter/Visual") as Polygon2D
	var staple_visual: Polygon2D = scene.get_node_or_null("Stations/StapleArea/Visual") as Polygon2D
	if player == null or counter_area == null or staple_area == null or counter_visual == null or staple_visual == null:
		_fail("single highlight", "missing player or station highlight nodes")
		return

	var counter_base: Color = counter_visual.color
	var staple_base: Color = staple_visual.color
	player.call("_update_highlighted_station", counter_area)
	if _colors_equal(counter_visual.color, counter_base):
		_fail("single highlight", "counter should be highlighted")
	if not _colors_equal(staple_visual.color, staple_base):
		_fail("single highlight", "staple should not be highlighted yet")

	player.call("_update_highlighted_station", staple_area)
	if not _colors_equal(counter_visual.color, counter_base):
		_fail("single highlight", "counter should be restored when staple is highlighted")
	if _colors_equal(staple_visual.color, staple_base):
		_fail("single highlight", "staple should be highlighted")

	player.call("_update_highlighted_station", null)
	if not _colors_equal(counter_visual.color, counter_base):
		_fail("single highlight", "counter should remain restored after clearing highlight")
	if not _colors_equal(staple_visual.color, staple_base):
		_fail("single highlight", "staple should be restored after clearing highlight")


func _colors_equal(a: Color, b: Color) -> bool:
	return is_equal_approx(a.r, b.r) and is_equal_approx(a.g, b.g) and is_equal_approx(a.b, b.b) and is_equal_approx(a.a, b.a)


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


func _action_has_key(action_name: String, keycode: int) -> bool:
	for event in InputMap.action_get_events(action_name):
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null and key_event.physical_keycode == keycode:
			return true
	return false


func _action_has_joy_button(action_name: String, button_index: int) -> bool:
	for event in InputMap.action_get_events(action_name):
		var button_event: InputEventJoypadButton = event as InputEventJoypadButton
		if button_event != null and button_event.button_index == button_index:
			return true
	return false


func _action_has_joy_motion(action_name: String, axis: int, sign_value: float) -> bool:
	for event in InputMap.action_get_events(action_name):
		var motion_event: InputEventJoypadMotion = event as InputEventJoypadMotion
		if motion_event == null or motion_event.axis != axis:
			continue
		if sign_value < 0.0 and motion_event.axis_value < -0.5:
			return true
		if sign_value > 0.0 and motion_event.axis_value > 0.5:
			return true
	return false


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
	takeout_bowl.setup_order(501, {"spinach": 1}, "noodle", "hot", "takeout", 0, 1)
	takeout_bowl.status = OrderBowl.STATUS_COOKED
	takeout_bowl.add_required_staple()
	_complete_sauce_requirements(manager, takeout_bowl)
	manager.interact_packing_area()
	manager.interact_packing_bag_area()
	manager.interact_surface_slot("TakeoutPickupSlot1")
	if manager.held_bowl != null or int(manager.completed_orders) != 1:
		_fail("delivery paths", "packed takeout should complete at takeout pickup slot")
		scene.queue_free()
		return

	var dine_bowl: OrderBowl = OrderBowl.new()
	scene.add_child(dine_bowl)
	dine_bowl.setup_order(502, {"spinach": 1}, "noodle", "hot", "dine_in", 2, 1)
	dine_bowl.status = OrderBowl.STATUS_COOKED
	dine_bowl.add_required_staple()
	_complete_sauce_requirements(manager, dine_bowl)
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


func _check_quality_penalty_delivery_rules() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("quality delivery", "restaurant manager was not found")
		scene.queue_free()
		return

	var dine_missing_sauce: OrderBowl = OrderBowl.new()
	scene.add_child(dine_missing_sauce)
	dine_missing_sauce.setup_order(520, {"spinach": 1}, "none", "mild", "dine_in", 1)
	dine_missing_sauce.status = OrderBowl.STATUS_COOKED
	manager._hold_bowl(dine_missing_sauce)
	manager.interact_delivery_table(1)
	if int(manager.completed_orders) != 1 or int(manager.money_today) >= 10 or int(manager.failed_orders) != 0:
		_fail("quality delivery", "dine-in missing sauce should complete with a money penalty")
		scene.queue_free()
		return

	var money_after_missing_sauce: int = int(manager.money_today)
	var dine_missing_chili: OrderBowl = OrderBowl.new()
	scene.add_child(dine_missing_chili)
	dine_missing_chili.setup_order(521, {"spinach": 1}, "none", "medium", "dine_in", 1, 2)
	dine_missing_chili.status = OrderBowl.STATUS_COOKED
	for sauce_id in ["garlic_water", "sesame_paste", "vinegar", "sugar"]:
		dine_missing_chili.add_mixed_sauce_once(sauce_id)
	manager._hold_bowl(dine_missing_chili)
	manager.interact_delivery_table(1)
	if int(manager.completed_orders) != 2 or int(manager.money_today) - money_after_missing_sauce >= 10:
		_fail("quality delivery", "dine-in missing chili should complete with a money penalty")
		scene.queue_free()
		return

	var empty_dine: OrderBowl = OrderBowl.new()
	scene.add_child(empty_dine)
	empty_dine.setup_order(522, {"spinach": 1}, "none", "mild", "dine_in", 1)
	empty_dine.set_empty_holder_visual()
	manager._hold_bowl(empty_dine)
	var completed_before_empty: int = int(manager.completed_orders)
	manager.interact_delivery_table(1)
	if int(manager.completed_orders) != completed_before_empty or manager.held_bowl != empty_dine:
		_fail("quality delivery", "dine-in empty bowl should not complete")
		scene.queue_free()
		return

	var wrong_staple: OrderBowl = OrderBowl.new()
	scene.add_child(wrong_staple)
	wrong_staple.setup_order(523, {"spinach": 1}, "noodle", "mild", "dine_in", 1)
	wrong_staple.status = OrderBowl.STATUS_COOKED
	wrong_staple.staple_added = true
	wrong_staple.actual_staple_type = "glass_noodle"
	manager._hold_bowl(wrong_staple)
	manager.interact_delivery_table(1)
	if int(manager.completed_orders) != completed_before_empty or manager.held_bowl != wrong_staple:
		_fail("quality delivery", "dine-in wrong staple should not complete")
		scene.queue_free()
		return

	var takeout_missing_sauce: OrderBowl = OrderBowl.new()
	scene.add_child(takeout_missing_sauce)
	takeout_missing_sauce.setup_order(524, {"spinach": 1}, "none", "mild", "takeout", 0)
	takeout_missing_sauce.status = OrderBowl.STATUS_COOKED
	manager._hold_bowl(takeout_missing_sauce)
	manager.interact_packing_area()
	if takeout_missing_sauce.status != OrderBowl.STATUS_SEALED:
		_fail("quality delivery", "takeout missing sauce should seal")
		scene.queue_free()
		return
	manager.interact_packing_bag_area()
	if takeout_missing_sauce.status != OrderBowl.STATUS_PACKED:
		_fail("quality delivery", "takeout missing sauce should pack")
		scene.queue_free()
		return

	var raw_takeout: OrderBowl = OrderBowl.new()
	scene.add_child(raw_takeout)
	raw_takeout.setup_order(525, {"spinach": 1}, "none", "mild", "takeout", 0)
	var raw_quality: Dictionary = manager._evaluate_order_quality(raw_takeout)
	if int(raw_quality.get("money", 10)) >= 10 or not str(raw_quality.get("message", "")).contains("没煮好"):
		_fail("quality delivery", "raw takeout quality should include 没煮好 penalty")
		scene.queue_free()
		return
	manager._hold_bowl(raw_takeout)
	manager.interact_packing_area()
	if raw_takeout.status != OrderBowl.STATUS_SEALED:
		_fail("quality delivery", "raw takeout should seal")
		scene.queue_free()
		return
	manager.interact_packing_bag_area()
	if raw_takeout.status != OrderBowl.STATUS_PACKED:
		_fail("quality delivery", "raw takeout should pack")
		scene.queue_free()
		return
	var money_before_raw_takeout: int = int(manager.money_today)
	manager.interact_surface_slot("TakeoutPickupSlot1")
	if int(manager.completed_orders) != 3 or int(manager.money_today) - money_before_raw_takeout >= 10:
		_fail("quality delivery", "raw takeout should complete with a strong money penalty")
		scene.queue_free()
		return

	var raw_dine: OrderBowl = OrderBowl.new()
	scene.add_child(raw_dine)
	raw_dine.setup_order(526, {"spinach": 1}, "none", "mild", "dine_in", 1)
	manager._hold_bowl(raw_dine)
	var completed_before_raw_dine: int = int(manager.completed_orders)
	manager.interact_delivery_table(1)
	if int(manager.completed_orders) != completed_before_raw_dine or manager.held_bowl != raw_dine:
		_fail("quality delivery", "raw dine-in should not complete")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("quality delivery")


func _check_takeout_bad_order_cleanup() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("bad takeout cleanup", "restaurant manager was not found")
		scene.queue_free()
		return

	var pot_content: OrderBowl = OrderBowl.new()
	scene.add_child(pot_content)
	pot_content.setup_order(900, {"spinach": 1}, "none", "mild", "takeout", 0)
	pot_content.status = OrderBowl.STATUS_COOKED
	manager.cooker_1.active_pot.add_order_bowl(pot_content)

	var empty_takeout: OrderBowl = OrderBowl.new()
	scene.add_child(empty_takeout)
	empty_takeout.setup_order(900, {"spinach": 1}, "none", "mild", "takeout", 0)
	empty_takeout.set_empty_holder_visual()
	var empty_quality: Dictionary = manager._evaluate_order_quality(empty_takeout)
	if int(empty_quality.get("money", -1)) != 0 or not str(empty_quality.get("message", "")).contains("空碗出单"):
		_fail("bad takeout cleanup", "empty takeout quality should stay the empty bowl result")
		scene.queue_free()
		return
	manager._hold_bowl(empty_takeout)
	manager.interact_packing_area()
	manager.interact_packing_bag_area()
	manager.interact_surface_slot("TakeoutPickupSlot1")
	if int(manager.completed_orders) != 1 or int(manager.money_today) != 0:
		_fail("bad takeout cleanup", "empty takeout should complete with zero money")
		scene.queue_free()
		return
	if manager.cooker_1.active_pot.content_bowl != null:
		_fail("bad takeout cleanup", "matching pot content should be cleared")
		scene.queue_free()
		return
	for tracked_bowl in manager._get_tracked_order_bowls():
		if tracked_bowl != null and tracked_bowl.order_id == 900:
			_fail("bad takeout cleanup", "completed bad order should not remain tracked")
			scene.queue_free()
			return

	var wrong_staple_takeout: OrderBowl = OrderBowl.new()
	scene.add_child(wrong_staple_takeout)
	wrong_staple_takeout.setup_order(901, {"spinach": 1}, "noodle", "mild", "takeout", 0)
	wrong_staple_takeout.status = OrderBowl.STATUS_COOKED
	wrong_staple_takeout.staple_added = true
	wrong_staple_takeout.actual_staple_type = "glass_noodle"
	var money_before_wrong_staple: int = int(manager.money_today)
	manager._hold_bowl(wrong_staple_takeout)
	manager.interact_packing_area()
	manager.interact_packing_bag_area()
	manager.interact_surface_slot("TakeoutPickupSlot1")
	if int(manager.completed_orders) != 2 or int(manager.money_today) - money_before_wrong_staple >= 10:
		_fail("bad takeout cleanup", "wrong staple takeout should complete with a money penalty")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("bad takeout cleanup")


func _check_order_timing_score() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("order timing", "restaurant manager was not found")
		scene.queue_free()
		return

	var early_bowl: OrderBowl = OrderBowl.new()
	scene.add_child(early_bowl)
	early_bowl.setup_order(530, {"spinach": 1}, "none", "mild", "dine_in", 1)
	early_bowl.status = OrderBowl.STATUS_COOKED
	_complete_sauce_requirements(manager, early_bowl)
	manager.interact_delivery_table(1)
	if int(manager.money_today) != 10 or int(manager.score_today) != 1:
		_fail("order timing", "early perfect order should give full money and good review")
		scene.queue_free()
		return

	var late_bowl: OrderBowl = OrderBowl.new()
	scene.add_child(late_bowl)
	late_bowl.setup_order(531, {"spinach": 1}, "none", "mild", "dine_in", 1)
	late_bowl.status = OrderBowl.STATUS_COOKED
	late_bowl.order_patience_current = late_bowl.order_patience_max * 0.1
	_complete_sauce_requirements(manager, late_bowl)
	manager.interact_delivery_table(1)
	if int(manager.money_today) != 20 or int(manager.score_today) != 1:
		_fail("order timing", "late perfect order should give money without extra good review")
		scene.queue_free()
		return

	var expired_bowl: OrderBowl = OrderBowl.new()
	scene.add_child(expired_bowl)
	expired_bowl.setup_order(532, {"spinach": 1}, "none", "mild", "dine_in", 1)
	expired_bowl.status = OrderBowl.STATUS_COOKED
	expired_bowl.order_patience_current = 0.0
	_complete_sauce_requirements(manager, expired_bowl)
	manager.interact_delivery_table(1)
	if int(manager.completed_orders) != 2 or int(manager.failed_orders) != 1:
		_fail("order timing", "expired order should fail instead of completing")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("order timing")


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
	if manager.cooker_1.active_bowl != bowl or manager.held_bowl == null or not manager.held_bowl.is_empty_holder:
		_fail("staple gate", "order with staple should enter pot and leave empty bowl")
		scene.queue_free()
		return
	if manager._get_tracked_order_bowls().has(manager.held_bowl):
		_fail("staple gate", "empty holder should not be tracked as active order")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("staple gate")


func _check_pots_spawn_on_stoves() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("pot spawn", "restaurant manager was not found")
		scene.queue_free()
		return
	if manager.cooker_1.active_pot == null or manager.cooker_2.active_pot == null:
		_fail("pot spawn", "both stoves should start with a pot")
		scene.queue_free()
		return
	if not manager.cooker_1.active_pot.is_empty() or not manager.cooker_2.active_pot.is_empty():
		_fail("pot spawn", "initial pots should be empty")
		scene.queue_free()
		return
	if manager.cooker_1.active_pot.get_content_status_text() != "空锅":
		_fail("pot spawn", "empty pot should show 空锅")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("pot spawn")


func _check_take_and_place_pot() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("pot move", "restaurant manager was not found")
		scene.queue_free()
		return

	var pot: CookingPot = manager.cooker_1.active_pot
	manager.interact_cooker(manager.cooker_1)
	if manager.held_pot != pot or manager.cooker_1.active_pot != null:
		_fail("pot move", "player should pick up the stove pot")
		scene.queue_free()
		return
	manager.interact_surface_slot("SurfaceSlot_r1c8")
	var slot: SurfaceSlot = manager._get_surface_slot("SurfaceSlot_r1c8")
	if manager.held_pot != null or slot == null or slot.get_stored_pot() != pot:
		_fail("pot move", "pot should be stored on surface slot")
		scene.queue_free()
		return
	manager.interact_surface_slot("SurfaceSlot_r1c8")
	if manager.held_pot != pot or not slot.is_empty():
		_fail("pot move", "pot should be picked back up from surface slot")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("pot move")


func _check_pot_heats_only_on_stove() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("pot heat", "restaurant manager was not found")
		scene.queue_free()
		return

	var bowl: OrderBowl = OrderBowl.new()
	scene.add_child(bowl)
	bowl.setup_order(701, {"spinach": 1}, "none", "mild", "takeout", 0)
	manager._hold_bowl(bowl)
	manager.interact_cooker(manager.cooker_1)
	var pot: CookingPot = manager.cooker_1.active_pot
	var pot_label: Label = pot.get_node_or_null("Label") as Label
	if pot_label != null and pot_label.text != "加热中":
		_fail("pot heat", "cooking pot should show 加热中 without order id")
		scene.queue_free()
		return
	pot.call("_process", 8.2)
	if pot.content_bowl == null or pot.content_bowl.status != OrderBowl.STATUS_COOKED:
		_fail("pot heat", "pot content should become READY on stove")
		scene.queue_free()
		return
	if pot_label != null and pot_label.text != "已熟":
		_fail("pot heat", "ready pot should show 已熟 without order id")
		scene.queue_free()
		return
	var holder: OrderBowl = manager.held_bowl
	var holder_label: Label = holder.get_node_or_null("OrderLabel") as Label
	if holder_label == null or not holder_label.text.contains("#701"):
		_fail("pot heat", "empty holder should display order id")
		scene.queue_free()
		return
	holder.queue_free()
	manager.held_bowl = null
	manager.interact_cooker(manager.cooker_1)
	manager.held_pot.call("_process", 10.0)
	if manager.held_pot.content_bowl == null or manager.held_pot.content_bowl.is_overcooked():
		_fail("pot heat", "ready pot should not overcook off heat")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("pot heat")


func _check_scoop_from_pot() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("pot scoop", "restaurant manager was not found")
		scene.queue_free()
		return

	var bowl: OrderBowl = OrderBowl.new()
	scene.add_child(bowl)
	bowl.setup_order(702, {"spinach": 1}, "none", "mild", "dine_in", 1)
	manager._hold_bowl(bowl)
	manager.interact_cooker(manager.cooker_1)
	manager.cooker_1.active_pot.content_bowl.update_cooking(8.2)
	var holder: OrderBowl = manager.held_bowl
	manager.interact_cooker(manager.cooker_1)
	if manager.held_bowl != holder or manager.held_bowl.is_empty_holder or manager.cooker_1.active_pot.content_bowl != null:
		_fail("pot scoop", "empty holder should scoop ready stove pot")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("pot scoop")


func _check_add_held_order_bowl_to_table_pot() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("held bowl to table pot", "restaurant manager was not found")
		scene.queue_free()
		return

	var pot: CookingPot = manager.cooker_1.active_pot
	manager.interact_cooker(manager.cooker_1)
	manager.interact_surface_slot("SurfaceSlot_r1c8")
	var slot: SurfaceSlot = manager._get_surface_slot("SurfaceSlot_r1c8")
	if slot == null or slot.get_stored_pot() != pot:
		_fail("held bowl to table pot", "empty pot should be on the surface slot")
		scene.queue_free()
		return

	var order_bowl: OrderBowl = OrderBowl.new()
	scene.add_child(order_bowl)
	order_bowl.setup_order(711, {"spinach": 1}, "noodle", "mild", "dine_in", 1)
	order_bowl.add_required_staple()
	manager._hold_bowl(order_bowl)
	manager.interact_surface_slot("SurfaceSlot_r1c8")

	if pot.content_bowl == null or pot.content_bowl.order_id != order_bowl.order_id:
		_fail("held bowl to table pot", "table pot should contain the order bowl")
		scene.queue_free()
		return
	if manager.held_bowl == null or not manager.held_bowl.is_empty_holder or manager.held_bowl.order_id != order_bowl.order_id:
		_fail("held bowl to table pot", "player should hold the matching empty bowl")
		scene.queue_free()
		return
	if pot.is_on_heat:
		_fail("held bowl to table pot", "table pot should not heat after receiving order")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("held bowl to table pot")


func _check_add_table_order_bowl_to_held_pot() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("table bowl to held pot", "restaurant manager was not found")
		scene.queue_free()
		return

	var slot: SurfaceSlot = manager._get_surface_slot("SurfaceSlot_r1c8")
	var order_bowl: OrderBowl = OrderBowl.new()
	scene.add_child(order_bowl)
	order_bowl.setup_order(712, {"spinach": 1}, "noodle", "mild", "dine_in", 1)
	order_bowl.add_required_staple()
	if slot == null or not slot.store_bowl(order_bowl):
		_fail("table bowl to held pot", "order bowl should be stored on the surface slot")
		scene.queue_free()
		return

	var pot: CookingPot = manager.cooker_1.active_pot
	manager.interact_cooker(manager.cooker_1)
	manager.interact_surface_slot("SurfaceSlot_r1c8")

	if manager.held_pot != pot or manager.held_pot.content_bowl == null or manager.held_pot.content_bowl.order_id != order_bowl.order_id:
		_fail("table bowl to held pot", "held pot should contain the table order")
		scene.queue_free()
		return
	var holder: OrderBowl = slot.get_stored_bowl()
	if holder == null or not holder.is_empty_holder or holder.order_id != order_bowl.order_id:
		_fail("table bowl to held pot", "surface slot should keep the matching empty bowl")
		scene.queue_free()
		return
	if manager.held_pot.is_on_heat:
		_fail("table bowl to held pot", "held pot should not heat after receiving order")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("table bowl to held pot")


func _check_cannot_add_order_to_pot_without_staple() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("order to pot without staple", "restaurant manager was not found")
		scene.queue_free()
		return

	var pot: CookingPot = manager.cooker_1.active_pot
	manager.interact_cooker(manager.cooker_1)
	manager.interact_surface_slot("SurfaceSlot_r1c8")

	var order_bowl: OrderBowl = OrderBowl.new()
	scene.add_child(order_bowl)
	order_bowl.setup_order(713, {"spinach": 1}, "noodle", "mild", "dine_in", 1)
	manager._hold_bowl(order_bowl)
	manager.interact_surface_slot("SurfaceSlot_r1c8")

	if pot.content_bowl != null:
		_fail("order to pot without staple", "pot should remain empty")
		scene.queue_free()
		return
	if manager.held_bowl != order_bowl or order_bowl.is_empty_holder:
		_fail("order to pot without staple", "player should still hold the original order bowl")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("order to pot without staple")


func _check_cannot_add_order_to_occupied_pot() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("order to occupied pot", "restaurant manager was not found")
		scene.queue_free()
		return

	var pot: CookingPot = manager.cooker_1.active_pot
	manager.interact_cooker(manager.cooker_1)
	manager.interact_surface_slot("SurfaceSlot_r1c8")

	var first_bowl: OrderBowl = OrderBowl.new()
	scene.add_child(first_bowl)
	first_bowl.setup_order(714, {"spinach": 1}, "none", "mild", "dine_in", 1)
	pot.add_order_bowl(first_bowl)

	var second_bowl: OrderBowl = OrderBowl.new()
	scene.add_child(second_bowl)
	second_bowl.setup_order(715, {"spinach": 1}, "none", "mild", "dine_in", 1)
	manager._hold_bowl(second_bowl)
	manager.interact_surface_slot("SurfaceSlot_r1c8")

	if pot.content_bowl == null or pot.content_bowl.order_id != first_bowl.order_id:
		_fail("order to occupied pot", "occupied pot should keep its original order")
		scene.queue_free()
		return
	if manager.held_bowl != second_bowl or second_bowl.is_empty_holder:
		_fail("order to occupied pot", "second order should stay in player hands")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("order to occupied pot")


func _check_empty_bowl_not_discarded_while_pot_has_content() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("empty bowl trash guard", "restaurant manager was not found")
		scene.queue_free()
		return

	var bowl: OrderBowl = OrderBowl.new()
	scene.add_child(bowl)
	bowl.setup_order(703, {"spinach": 1}, "none", "mild", "dine_in", 1)
	manager._hold_bowl(bowl)
	manager.interact_cooker(manager.cooker_1)

	var holder: OrderBowl = manager.held_bowl
	if holder == null or not holder.is_empty_holder:
		_fail("empty bowl trash guard", "order entering pot should leave an empty holder bowl")
		scene.queue_free()
		return
	if manager.cooker_1.active_pot == null or manager.cooker_1.active_pot.content_bowl == null:
		_fail("empty bowl trash guard", "order content should be in the pot")
		scene.queue_free()
		return

	var failed_before: int = int(manager.failed_orders)
	manager.interact_trash_bin()
	if manager.held_bowl != holder or not is_instance_valid(holder) or not holder.is_empty_holder:
		_fail("empty bowl trash guard", "trash should keep empty holder for active order content")
		scene.queue_free()
		return
	if manager.cooker_1.active_pot.content_bowl == null:
		_fail("empty bowl trash guard", "trash should not clear pot content when guarding empty holder")
		scene.queue_free()
		return
	if int(manager.failed_orders) != failed_before:
		_fail("empty bowl trash guard", "guarded empty holder should not count as failed")
		scene.queue_free()
		return

	var status_label: Label = manager.ui.get("status_label") as Label
	var status_text: String = status_label.text if status_label != null else ""
	if status_text.contains("#") or status_text.contains("703"):
		_fail("empty bowl trash guard", "empty holder guard prompt should not reveal order id")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("empty bowl trash guard")


func _check_empty_pot_and_empty_bowl_do_not_block_day_end() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("empty hand day end", "restaurant manager was not found")
		scene.queue_free()
		return

	manager.is_day_open = false
	manager.queued_customers.clear()
	manager.waiting_customers_by_order_id.clear()
	for customer_node in get_nodes_in_group("restaurant_customers"):
		if customer_node != null and is_instance_valid(customer_node):
			customer_node.queue_free()
	await process_frame

	manager.held_dirty_cooker = null
	manager.held_bowl = null
	manager.held_pot = null
	manager.waiting_area.bowls.clear()
	for cooker in [manager.cooker_1, manager.cooker_2]:
		if cooker != null and cooker.active_pot != null:
			var cleared_bowl: OrderBowl = cooker.clear_active_bowl()
			if cleared_bowl != null:
				cleared_bowl.queue_free()

	manager.held_pot = manager.cooker_1.active_pot
	if manager._has_active_restaurant_work():
		_fail("empty hand day end", "empty held pot should not block day end")
		scene.queue_free()
		return

	manager.held_pot = null
	var holder: OrderBowl = OrderBowl.new()
	scene.add_child(holder)
	holder.setup_order(704, {"spinach": 1}, "none", "mild", "dine_in", 1)
	holder.set_empty_holder_visual()
	manager.held_bowl = holder
	if manager._has_active_restaurant_work():
		_fail("empty hand day end", "empty holder bowl should not block day end")
		scene.queue_free()
		return

	holder.is_empty_holder = false
	holder.status = OrderBowl.STATUS_WAITING
	if not manager._has_active_restaurant_work():
		_fail("empty hand day end", "non-empty held bowl should count as active work")
		scene.queue_free()
		return

	manager.held_bowl = null
	holder.queue_free()
	var content_bowl: OrderBowl = OrderBowl.new()
	scene.add_child(content_bowl)
	content_bowl.setup_order(705, {"spinach": 1}, "none", "mild", "takeout", 0)
	var pot: CookingPot = manager.cooker_1.active_pot
	pot.content_bowl = content_bowl
	manager.held_pot = pot
	if not manager._has_active_restaurant_work():
		_fail("empty hand day end", "held pot with content should count as active work")
		scene.queue_free()
		return

	scene.queue_free()
	_pass("empty hand day end")


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

	if absf(counter_shape.position.x) > 0.1 or absf(staple_shape.position.x) > 0.1 or absf(counter_shape.position.y) > 0.1 or absf(staple_shape.position.y) > 0.1:
		_fail("staple interaction", "counter and staple interaction shapes should be centered")
		scene.queue_free()
		return

	var counter_rect: RectangleShape2D = counter_shape.shape as RectangleShape2D
	var staple_rect: RectangleShape2D = staple_shape.shape as RectangleShape2D
	if counter_rect == null or staple_rect == null or counter_rect.size.x < 40.0 or counter_rect.size.x > 52.0 or counter_rect.size.y < 34.0 or counter_rect.size.y > 44.0 or staple_rect.size.x < 40.0 or staple_rect.size.x > 52.0 or staple_rect.size.y < 34.0 or staple_rect.size.y > 44.0:
		_fail("staple interaction", "counter and staple interaction shapes should be centered and about one grid cell")
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


func _check_visible_text_is_chinese() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("chinese text", "restaurant manager was not found")
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

	var expected_fragments: Array[String] = ["等待", "空锅", "拿着订单 #605", "剩余 13 秒", "可出餐", "已熟", "煮糊"]
	for expected in expected_fragments:
		var found: bool = false
		for text in texts:
			if text.contains(expected):
				found = true
				break
		if not found:
			_fail("chinese text", "visible text should contain Chinese fragment: %s" % expected)
			ui.queue_free()
			scene.queue_free()
			return

	ui.queue_free()
	scene.queue_free()
	_pass("chinese text")


func _check_placeholder_interactions_do_not_mutate() -> void:
	RestaurantRunState.start_new_run(3)
	var scene_resource: PackedScene = load("res://scenes/gameplay/test_restaurant.tscn")
	var scene: Node = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame

	var manager: RestaurantGameManager = get_first_node_in_group("restaurant_game_manager") as RestaurantGameManager
	if manager == null:
		_fail("placeholder interaction", "restaurant manager was not found")
		scene.queue_free()
		return

	manager.completed_orders = 2
	manager.failed_orders = 1
	manager.money_today = 30
	var completed_before: int = manager.completed_orders
	var failed_before: int = manager.failed_orders
	var money_before: int = manager.money_today

	var placeholder_names: Array[String] = [
		"IngredientDisplay2",
		"DrinkStorage",
		"CookerStationLocked",
		"DiningTable3",
	]
	for station_name in placeholder_names:
		manager.interact_with_station(station_name)
		if manager.completed_orders != completed_before or manager.failed_orders != failed_before or manager.money_today != money_before:
			_fail("placeholder interaction", "%s changed core state" % station_name)
			scene.queue_free()
			return

	scene.queue_free()
	_pass("placeholder interaction")


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
	bowl.setup_order(603, {"spinach": 1}, "none", "mild", "takeout", 0, 1)
	bowl.status = OrderBowl.STATUS_COOKED
	manager._hold_bowl(bowl)
	var completed_before: int = int(manager.completed_orders)
	_complete_sauce_requirements(manager, bowl)
	manager.interact_packing_area()
	if bowl.status != OrderBowl.STATUS_SEALED:
		_fail("takeout slot", "sauced takeout should become sealed")
		scene.queue_free()
		return

	manager.interact_surface_slot("TakeoutPickupSlot1")
	var slot: SurfaceSlot = manager._get_surface_slot("TakeoutPickupSlot1")
	if int(manager.completed_orders) != completed_before:
		_fail("takeout slot", "sealed takeout should not complete")
		scene.queue_free()
		return
	if slot == null or slot.get_stored_bowl() != bowl:
		_fail("takeout slot", "sealed takeout should remain on pickup slot")
		scene.queue_free()
		return

	manager.interact_surface_slot("TakeoutPickupSlot1")
	if manager.held_bowl != bowl:
		_fail("takeout slot", "sealed takeout should be picked back up")
		scene.queue_free()
		return
	manager.interact_packing_bag_area()
	if bowl.status != OrderBowl.STATUS_PACKED:
		_fail("takeout slot", "sealed takeout should become packed at bag area")
		scene.queue_free()
		return
	manager.interact_surface_slot("TakeoutPickupSlot1")

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
	if manager.held_bowl == null or not manager.held_bowl.is_empty_holder:
		_fail("overcooked trash", "order entering pot should leave an empty holder bowl")
		scene.queue_free()
		return

	manager.cooker_1.active_bowl.update_cooking(14.2)
	if not manager.cooker_1.active_bowl.is_overcooked():
		_fail("overcooked trash", "order did not overcook")
		scene.queue_free()
		return
	var over_pot_label: Label = manager.cooker_1.active_pot.get_node_or_null("Label") as Label
	if over_pot_label != null and over_pot_label.text != "煮糊":
		_fail("overcooked trash", "overcooked pot should show 煮糊 without order id")
		scene.queue_free()
		return

	manager.held_bowl.queue_free()
	manager.held_bowl = null
	manager.interact_cooker(manager.cooker_1)
	if manager.held_bowl != null:
		_fail("overcooked trash", "empty holder should be cleared when picking up overcooked pot")
		scene.queue_free()
		return
	if manager.held_pot == null or not manager.held_pot.has_overcooked_content():
		_fail("overcooked trash", "overcooked pot should be held as a pot")
		scene.queue_free()
		return
	if manager.cooker_1.active_pot != null:
		_fail("overcooked trash", "stove should be empty after picking up overcooked pot")
		scene.queue_free()
		return

	var completed_before: int = int(manager.completed_orders)
	var failed_before: int = int(manager.failed_orders)
	manager.interact_sauce_station()
	if manager.held_pot == null or not manager.held_pot.has_overcooked_content():
		_fail("overcooked trash", "sauce station should not clear held overcooked pot")
		scene.queue_free()
		return

	manager.interact_trash_bin()
	if manager.held_pot == null:
		_fail("overcooked trash", "trash bin should leave the empty pot in hand")
		scene.queue_free()
		return
	if not manager.held_pot.is_empty():
		_fail("overcooked trash", "trash bin did not clear the overcooked pot")
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

	manager.interact_cooker(manager.cooker_1)
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
	manager.held_pot = null
	var cooker_2_pot: CookingPot = manager.cooker_2.active_pot
	manager.interact_cooker(manager.cooker_2)
	if manager.held_pot == null or manager.held_pot != cooker_2_pot:
		_fail("overcooked trash", "player should hold the overcooked pot they interacted with")
		scene.queue_free()
		return
	manager.interact_trash_bin()
	if manager.held_pot == null or not manager.held_pot.is_empty():
		_fail("overcooked trash", "trash should clear the held overcooked pot")
		scene.queue_free()
		return
	if manager.cooker_1.active_bowl == null:
		_fail("overcooked trash", "trash should not clear a different overcooked pot")
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
	takeout_bowl.setup_order(401, {"spinach": 1}, "noodle", "hot", "takeout", 0, 2)
	takeout_bowl.add_mixed_sauce_once("garlic_water")
	var takeout_text: String = manager._get_order_card_text(takeout_bowl)
	if not takeout_text.contains("外带桌"):
		_fail("order card destination", "takeout card should show pickup destination")
		scene.queue_free()
		return
	if not takeout_text.contains("#401") or not takeout_text.contains("耐心：100%") or not takeout_text.contains("主食：面"):
		_fail("order card destination", "takeout card should keep id and patience")
		scene.queue_free()
		return
	if not takeout_text.contains("小料：1/4") or not takeout_text.contains("辣椒：0/2"):
		_fail("order card destination", "takeout card should show sauce and chili progress")
		scene.queue_free()
		return

	var dine_bowl: OrderBowl = OrderBowl.new()
	dine_bowl.setup_order(402, {"spinach": 1}, "noodle", "hot", "dine_in", 2, 3)
	var dine_text: String = manager._get_order_card_text(dine_bowl)
	if not dine_text.contains("桌2"):
		_fail("order card destination", "dine-in card should show table destination")
		scene.queue_free()
		return
	if not dine_text.contains("#402") or not dine_text.contains("耐心：100%") or not dine_text.contains("主食：面"):
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
	ui.update_hand_state("拿着订单 #001")
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
	if not time_label.text.contains("剩余 13 秒"):
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
	manager.held_pot = null
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
	manager.held_pot = null
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


func _complete_sauce_requirements(manager: RestaurantGameManager, bowl: OrderBowl) -> void:
	if manager == null or bowl == null:
		return
	manager.held_bowl = bowl
	for action_name in ["sauce_x", "sauce_y", "sauce_a", "sauce_b"]:
		manager.interact_with_station_action("SauceStationMixed", action_name)
	for i in range(bowl.required_chili_count):
		manager.interact_with_station_action("SauceStation", "sauce_x")


func _finish() -> void:
	if failures.is_empty():
		print("Restaurant smoke check passed.")
		quit(0)
		return

	for failure in failures:
		print("Restaurant smoke failure: ", failure)
	quit(1)
