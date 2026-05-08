extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print(_text("LOG_SMOKE_START", "Starting minimal gameplay smoke check."))

	RunSetupData.reset_run_setup()
	RunSetupData.setup_stage_run("stage_1", 2)
	_pass("stage setup")

	var scene_resource = load("res://scenes/gameplay/main.tscn")
	if scene_resource == null:
		_fail("startup", "main scene could not be loaded")
		_finish()
		return

	var main_scene = scene_resource.instantiate()
	get_root().add_child(main_scene)
	await process_frame
	await process_frame

	var manager = get_first_node_in_group("game_manager")
	if manager == null:
		_fail("startup", "GameManager was not found")
		_finish()
		return

	if not manager.debug_validate_runtime():
		_fail("startup", "GameManager runtime validation failed")
		_finish()
		return
	_pass("startup")

	manager.max_queue_size = 0
	manager.open_business()
	if not manager.is_open_for_business:
		_fail("open business", "business did not open")
	_finish_if_failed()
	if not failures.is_empty():
		return
	_pass("open business")

	_run_order_flow(manager)
	if not failures.is_empty():
		_finish()
		return

	_run_restock_flow(manager)
	if not failures.is_empty():
		_finish()
		return

	manager.close_business()
	await process_frame
	if not manager.is_cleanup_phase:
		_fail("close business", "cleanup phase was not reached")
	_finish_if_failed()
	if not failures.is_empty():
		return
	_pass("close business")

	var remaining_cooked_stock: Dictionary = manager.cooked_stock.duplicate(true)
	var remaining_raw_stock: Dictionary = manager.raw_stock.duplicate(true)
	var remaining_staple_stock: Dictionary = manager.staple_stock.duplicate(true)
	var input: Dictionary = manager._build_settlement_summary_input(
		remaining_cooked_stock,
		remaining_raw_stock,
		remaining_staple_stock,
		{}
	)
	var day_summary: Dictionary = manager.settlement_builder.build_day_summary(input)
	var run_summary: Dictionary = manager.settlement_builder.build_run_summary(input)

	if day_summary.is_empty():
		_fail("day settlement", "day summary is empty")
	if run_summary.is_empty():
		_fail("run settlement", "run summary is empty")

	_finish_if_failed()
	if not failures.is_empty():
		return

	RunSetupData.set_day_summary(day_summary)
	RunSetupData.set_run_summary(run_summary)
	_pass("settlement summaries")
	_finish()


func _run_order_flow(manager: Node) -> void:
	manager.cooked_stock = {"spinach": 1, "potato_slice": 0, "tofu_puff": 0}
	manager.raw_stock = {"spinach": 1, "potato_slice": 0, "tofu_puff": 0}
	manager.staple_stock = {"glass_noodle": 1, "noodle": 1}
	RunSetupData.set_stock_state(manager.raw_stock, manager.cooked_stock, manager.staple_stock)

	var instant_customer: Node = _make_customer(manager, {"spinach": 1}, "none")
	manager.queued_customers.append(instant_customer)
	manager.begin_checkout_for_customer(instant_customer)
	var instant_result: Dictionary = manager.confirm_checkout_and_create_order(instant_customer)
	if not bool(instant_result.get("success", false)):
		_fail("checkout", "instant checkout failed")
		return
	_pass("checkout")

	var waiting_customer: Node = _make_customer(manager, {"spinach": 1}, "none")
	manager.queued_customers.append(waiting_customer)
	manager.begin_checkout_for_customer(waiting_customer)
	var waiting_result: Dictionary = manager.confirm_checkout_and_create_order(waiting_customer)
	if not bool(waiting_result.get("success", false)):
		_fail("waiting order", "waiting checkout failed")
		return
	if not manager.pending_order_system.has(waiting_customer):
		_fail("waiting order", "waiting customer was not added to pending orders")
		return
	_pass("waiting order")

	manager.cooking_system.add_to_cart_pot_selection("spinach", 1)
	manager.cooking_system.start_cart_pot_batch_cooking()
	manager.cooking_system.update_cart_pot(999.0)
	manager.interact_with_delivery_point()

	if manager.pending_order_system.has(waiting_customer):
		_fail("delivery", "waiting customer was not delivered")
		return
	_pass("cooking and delivery")


func _run_restock_flow(manager: Node) -> void:
	var before_supplier_stock: int = int(manager.raw_stock.get("potato_slice", 0))
	var was_open_for_business: bool = manager.is_open_for_business
	manager.is_open_for_business = false
	manager.supplier_system.place_order("potato_slice", 1)
	manager.supplier_system.update(999.0)
	manager.is_open_for_business = was_open_for_business
	if int(manager.raw_stock.get("potato_slice", 0)) <= before_supplier_stock:
		_fail("supplier restock", "supplier order did not increase stock")
		return
	_pass("supplier restock")

	manager.raw_stock = {"spinach": 0, "potato_slice": 0, "tofu_puff": 0}
	manager.cooked_stock = {"spinach": 0, "potato_slice": 0, "tofu_puff": 0}
	RunSetupData.set_stock_state(manager.raw_stock, manager.cooked_stock, manager.staple_stock)

	var shortage_customer: Node = _make_customer(manager, {"tofu_puff": 1}, "none")
	manager.queued_customers.append(shortage_customer)
	manager.begin_checkout_for_customer(shortage_customer)
	var shortage_result: Dictionary = manager.confirm_checkout_and_create_order(shortage_customer)
	if not bool(shortage_result.get("success", false)):
		_fail("emergency purchase", "shortage checkout failed")
		return

	if not manager.emergency_purchase_system.purchase_for_waiting_shortages():
		_fail("emergency purchase", "purchase_for_waiting_shortages returned false")
		return
	_pass("emergency purchase")


func _make_customer(manager: Node, ingredients: Dictionary, main_food_id: String) -> Node:
	var customer: Node = manager.customer_scene.instantiate()
	manager.characters_node.add_child(customer)
	customer.set_ingredients(ingredients)
	customer.set("main_food_id", main_food_id)
	customer.set("is_in_queue", true)
	customer.set("queue_index", 0)
	customer.set("current_state", 2)
	return customer


func _pass(step_name: String) -> void:
	print(_text("LOG_SMOKE_STEP_OK", "Smoke step passed: %s") % step_name)


func _fail(step_name: String, reason: String) -> void:
	failures.append("%s: %s" % [step_name, reason])
	push_error("Smoke failed at %s: %s" % [step_name, reason])


func _finish_if_failed() -> void:
	if failures.is_empty():
		return
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print(_text("LOG_SMOKE_DONE", "Smoke check passed."))
		quit(0)
		return

	for failure in failures:
		print("Smoke failure: ", failure)
	quit(1)


func _text(key: String, fallback: String) -> String:
	if get_root().get_node_or_null("/root/TextDB") != null:
		return TextDB.get_text(key)
	return fallback
