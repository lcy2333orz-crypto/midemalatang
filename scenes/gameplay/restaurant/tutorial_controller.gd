class_name TutorialController
extends Node

@export var tutorial_enabled: bool = true

var manager: RestaurantGameManager = null
var ui: RestaurantUI = null
var enabled: bool = false
var current_step_index: int = 0
var steps: Array[Dictionary] = []
var completed_step_ids: Dictionary = {}
var tutorial_order_index: int = 1
var forced_overcook_order_id: int = 0
var waiting_for_refill_order_id: int = 0

var highlighted_area: RestaurantStationArea = null
var finished: bool = false


func _ready() -> void:
	_build_day_1_steps()


func setup(new_manager: RestaurantGameManager, new_ui: RestaurantUI) -> void:
	manager = new_manager
	ui = new_ui
	_build_day_1_steps()

	if manager == null:
		push_warning("TutorialController setup: RestaurantGameManager not found.")
	if ui == null:
		push_warning("TutorialController setup: RestaurantUI not found.")

	enabled = tutorial_enabled and int(RestaurantRunState.current_day) == 1
	current_step_index = 0
	completed_step_ids.clear()
	tutorial_order_index = 1
	forced_overcook_order_id = 0
	waiting_for_refill_order_id = 0
	finished = false

	if not enabled:
		_clear_highlight()
		if ui != null and ui.has_method("hide_tutorial_text"):
			ui.hide_tutorial_text()
		return

	_show_current_step()


func controls_customer_spawning() -> bool:
	return enabled


func pauses_time() -> bool:
	return enabled


func get_first_order_override() -> Dictionary:
	return {
		"service_mode": "dine_in",
		"table_id": 1,
		"staple_type": "glass_noodle",
		"required_chili_count": 0
	}


func get_second_order_override() -> Dictionary:
	return {
		"service_mode": "dine_in",
		"table_id": 2,
		"staple_type": "noodle",
		"required_chili_count": 1,
		"force_overcook_once": true
	}


func is_forced_overcook_order(order_id: int) -> bool:
	return order_id > 0 and order_id == forced_overcook_order_id and waiting_for_refill_order_id == order_id


func notify_event(event_name: String, payload: Dictionary = {}) -> void:
	if not enabled or finished:
		return
	if current_step_index < 0 or current_step_index >= steps.size():
		return

	var step: Dictionary = steps[current_step_index]
	var wait_type: String = str(step.get("wait_type", ""))
	if not _event_completes_wait(wait_type, event_name, payload, step):
		return

	_advance_step()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or finished:
		return
	var is_confirm: bool = event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")
	if not is_confirm:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event != null and key_event.echo:
		return
	var step: Dictionary = steps[current_step_index] if current_step_index < steps.size() else {}
	if str(step.get("wait_type", "")) == "confirm":
		get_viewport().set_input_as_handled()
		_advance_step()


func _build_day_1_steps() -> void:
	steps = [
		{
			"id": "intro_1",
			"text": "小猫：欢迎来到培训店。先学会做第一份麻辣烫。",
			"target_station": "",
			"wait_type": "confirm"
		},
		{
			"id": "intro_2",
			"text": "小猫：顾客会自己选菜，然后来到收银台。",
			"target_station": "",
			"wait_type": "confirm"
		},
		{
			"id": "intro_3",
			"text": "小猫：看到提示后，按 H 继续。",
			"target_station": "",
			"wait_type": "confirm"
		},
		{
			"id": "wait_counter_order",
			"text": "等顾客到收银台。站到收银台旁边，按 H 接单。",
			"target_station": "Counter",
			"wait_type": "counter_order_created"
		},
		{
			"id": "add_staple",
			"text": "你拿到了订单盆。订单需要主食：粉丝。去主食柜按 H。",
			"target_station": "StapleArea",
			"wait_type": "held_bowl_has_staple"
		},
		{
			"id": "put_in_pot",
			"text": "主食加好了。把订单盆倒进锅里。",
			"target_station": "CookerStation1",
			"wait_type": "bowl_in_pot"
		},
		{
			"id": "scoop_cooked_bowl",
			"text": "等锅显示“已熟”。拿着对应空碗，对锅按 H 盛出。",
			"target_station": "CookerStation1",
			"wait_type": "held_bowl_cooked"
		},
		{
			"id": "mixed_sauces",
			"text": "去小料桶。按 H、J、K、L，各加一种小料。",
			"target_station": "SauceStationMixed",
			"wait_type": "mixed_sauces_complete"
		},
		{
			"id": "deliver_table_1",
			"text": "这单不要辣椒。把碗送到桌1。",
			"target_station": "DiningTable1",
			"wait_type": "dine_order_completed"
		},
		{
			"id": "first_order_done",
			"text": "第一份完成。按 H 继续下一单。",
			"target_station": "",
			"wait_type": "confirm"
		},
		{
			"id": "second_intro",
			"text": "下一单会用到辣椒。按 H 继续。",
			"target_station": "",
			"wait_type": "confirm"
		},
		{
			"id": "second_counter",
			"text": "等顾客到收银台。按 H 接单。",
			"target_station": "Counter",
			"wait_type": "counter_order_created"
		},
		{
			"id": "second_staple",
			"text": "这单需要主食：面。去主食柜按 H。",
			"target_station": "StapleArea",
			"wait_type": "held_bowl_has_staple"
		},
		{
			"id": "second_pot",
			"text": "把订单盆倒进锅里。这次会演示食物煮糊后的处理。",
			"target_station": "CookerStation1",
			"wait_type": "bowl_in_pot"
		},
		{
			"id": "second_overcooked",
			"text": "食物煮糊了。先把锅从锅位上拿起来。",
			"target_station": "CookerStation1",
			"wait_type": "overcooked_pot_picked_up"
		},
		{
			"id": "second_clear_overcook",
			"text": "拿着糊锅去厨房垃圾桶，按 H 倒掉糊掉的食物。",
			"target_station": "TrashBin",
			"wait_type": "tutorial_overcook_cleared"
		},
		{
			"id": "second_refill_prepare",
			"text": "现在你手里是空锅。先把空锅放回锅位。",
			"target_station": "CookerStation1",
			"wait_type": "held_pot_placed_on_cooker"
		},
		{
			"id": "second_refill_pick_bowl",
			"text": "拿起旁边的待补配订单盆。",
			"target_station": "SurfaceSlot_r1c8",
			"wait_type": "held_refill_bowl"
		},
		{
			"id": "second_refill",
			"text": "拿着待补配订单盆去食材柜，按 H 补回配菜。",
			"target_station": "IngredientDisplay",
			"wait_type": "bowl_refilled"
		},
		{
			"id": "second_restaple",
			"text": "补配完成。再去主食柜按 H，重新加入面。",
			"target_station": "StapleArea",
			"wait_type": "held_bowl_has_staple"
		},
		{
			"id": "second_recook",
			"text": "把订单盆重新倒进锅里。",
			"target_station": "CookerStation1",
			"wait_type": "bowl_in_pot"
		},
		{
			"id": "second_scoop",
			"text": "等锅显示“已熟”，用对应空碗盛出。",
			"target_station": "CookerStation1",
			"wait_type": "held_bowl_cooked"
		},
		{
			"id": "second_mixed_sauces",
			"text": "去小料桶。按 H、J、K、L，各加一种小料。",
			"target_station": "SauceStationMixed",
			"wait_type": "mixed_sauces_complete"
		},
		{
			"id": "second_chili",
			"text": "这单需要 1 次辣椒。去辣椒格按 H 一次。",
			"target_station": "SauceStation",
			"wait_type": "chili_complete"
		},
		{
			"id": "second_deliver",
			"text": "把这份麻辣烫送到桌2。",
			"target_station": "DiningTable2",
			"wait_type": "dine_order_completed"
		},
		{
			"id": "second_done",
			"text": "第二份完成。按 H 继续。",
			"target_station": "",
			"wait_type": "confirm"
		}
	]


func _event_completes_wait(wait_type: String, event_name: String, payload: Dictionary, step: Dictionary) -> bool:
	match wait_type:
		"counter_order_created":
			return event_name == "counter_order_created" and _event_matches_current_order(payload)
		"held_bowl_has_staple":
			var bowl: OrderBowl = payload.get("bowl", null) as OrderBowl
			return event_name == "held_bowl_has_staple" and _is_current_order_bowl(bowl) and bowl.is_staple_ready_for_cooking()
		"bowl_in_pot":
			var pot_bowl: OrderBowl = payload.get("bowl", null) as OrderBowl
			if event_name != "bowl_in_pot" or not _is_current_order_bowl(pot_bowl):
				return false
			if str(step.get("id", "")) == "second_pot" and forced_overcook_order_id == 0:
				forced_overcook_order_id = pot_bowl.order_id
				waiting_for_refill_order_id = pot_bowl.order_id
				pot_bowl.force_overcooked_for_tutorial()
				_refresh_manager_cookers()
			return true
		"held_bowl_cooked":
			var cooked_bowl: OrderBowl = payload.get("bowl", null) as OrderBowl
			return event_name == "held_bowl_cooked" and _is_current_order_bowl(cooked_bowl) and cooked_bowl.status == OrderBowl.STATUS_COOKED
		"mixed_sauces_complete":
			var sauced_bowl: OrderBowl = payload.get("bowl", null) as OrderBowl
			return event_name == "sauce_changed" and _is_current_order_bowl(sauced_bowl) and sauced_bowl.has_all_required_mixed_sauces()
		"chili_complete":
			var chili_bowl: OrderBowl = payload.get("bowl", null) as OrderBowl
			return (event_name == "sauce_changed" or event_name == "chili_changed") and _is_current_order_bowl(chili_bowl) and chili_bowl.added_chili_count == chili_bowl.required_chili_count
		"dine_order_completed":
			return event_name == "order_completed" and str(payload.get("service_mode", "")) == "dine_in"
		"overcooked_pot_picked_up":
			return event_name == "overcooked_pot_picked_up" and int(payload.get("order_id", 0)) == forced_overcook_order_id
		"tutorial_overcook_cleared":
			var refill_bowl: OrderBowl = payload.get("bowl", null) as OrderBowl
			return event_name == "tutorial_overcook_cleared" and _is_current_order_bowl(refill_bowl) and refill_bowl.needs_refill
		"held_pot_placed_on_cooker":
			return event_name == "pot_placed_on_cooker"
		"held_refill_bowl":
			var picked_bowl: OrderBowl = payload.get("bowl", null) as OrderBowl
			return event_name == "refill_bowl_picked_up" and _is_current_order_bowl(picked_bowl) and picked_bowl.needs_refill
		"bowl_refilled":
			var refilled_bowl: OrderBowl = payload.get("bowl", null) as OrderBowl
			var refilled: bool = event_name == "bowl_refilled" and _is_current_order_bowl(refilled_bowl) and not refilled_bowl.needs_refill
			if refilled:
				waiting_for_refill_order_id = 0
			return refilled
		_:
			return false


func _advance_step() -> void:
	if current_step_index >= 0 and current_step_index < steps.size():
		var completed_id: String = str(steps[current_step_index].get("id", ""))
		if completed_id != "":
			completed_step_ids[completed_id] = true

	current_step_index += 1
	if current_step_index >= steps.size():
		_finish_tutorial()
		return
	_show_current_step()


func _show_current_step() -> void:
	if not enabled or current_step_index < 0 or current_step_index >= steps.size():
		return
	var step: Dictionary = steps[current_step_index]
	_prepare_step(str(step.get("id", "")))
	if ui != null and ui.has_method("show_tutorial_text"):
		ui.show_tutorial_text(str(step.get("text", "")))
	_set_target_station(str(step.get("target_station", "")))


func _prepare_step(step_id: String) -> void:
	if step_id == "wait_counter_order":
		tutorial_order_index = 1
		if manager != null:
			manager.next_tutorial_order = get_first_order_override()
		_spawn_next_tutorial_customer_if_needed()
	elif step_id == "second_counter":
		tutorial_order_index = 2
		if manager != null:
			manager.next_tutorial_order = get_second_order_override()
		_spawn_next_tutorial_customer_if_needed()


func _spawn_next_tutorial_customer_if_needed() -> void:
	if manager == null or not manager.is_day_open:
		return
	if manager._get_counter_customer() != null:
		return
	if not manager.queued_customers.is_empty():
		return
	for customer_node in manager.get_tree().get_nodes_in_group("restaurant_customers"):
		var customer: RestaurantCustomer = customer_node as RestaurantCustomer
		if customer != null and is_instance_valid(customer):
			return
	manager.spawn_customer()


func _finish_tutorial() -> void:
	finished = true
	enabled = false
	_clear_highlight()
	if ui != null and ui.has_method("show_tutorial_text"):
		ui.show_tutorial_text("当前教学到这里。")


func _is_current_order_bowl(bowl: OrderBowl) -> bool:
	if bowl == null:
		return false
	if tutorial_order_index == 1:
		return bowl.service_mode == "dine_in" and bowl.table_id == 1
	return bowl.service_mode == "dine_in" and bowl.table_id == 2


func _event_matches_current_order(payload: Dictionary) -> bool:
	var bowl: OrderBowl = payload.get("bowl", null) as OrderBowl
	return _is_current_order_bowl(bowl)


func _refresh_manager_cookers() -> void:
	if manager == null:
		return
	for cooker in [manager.cooker_1, manager.cooker_2]:
		if cooker != null and is_instance_valid(cooker):
			if cooker.active_pot != null:
				cooker.active_pot.refresh_visual()
			cooker._sync_compat_bowl()
			cooker._update_status_label()


func _set_target_station(station_name: String) -> void:
	_clear_highlight()
	if station_name.strip_edges() == "" or manager == null:
		return

	var area: RestaurantStationArea = _find_station_area(station_name)
	if area == null:
		push_warning("TutorialController: target station not found: %s" % station_name)
		return

	highlighted_area = area
	highlighted_area.set_highlighted(true)


func _clear_highlight() -> void:
	if highlighted_area != null and is_instance_valid(highlighted_area):
		highlighted_area.set_highlighted(false)
	highlighted_area = null


func _find_station_area(station_name: String) -> RestaurantStationArea:
	var root: Node = manager.get_parent()
	if root == null:
		return null
	return _find_station_area_recursive(root, station_name)


func _find_station_area_recursive(node: Node, station_name: String) -> RestaurantStationArea:
	var area: RestaurantStationArea = node as RestaurantStationArea
	if area != null and area.station_name == station_name:
		return area
	for child in node.get_children():
		var found: RestaurantStationArea = _find_station_area_recursive(child, station_name)
		if found != null:
			return found
	return null
