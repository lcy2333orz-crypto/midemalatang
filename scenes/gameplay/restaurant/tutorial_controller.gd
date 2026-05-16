class_name TutorialController
extends Node

@export var tutorial_enabled: bool = true

var manager: RestaurantGameManager = null
var ui: RestaurantUI = null
var enabled: bool = false
var current_step_index: int = 0
var steps: Array[Dictionary] = []
var completed_step_ids: Dictionary = {}

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
	finished = false

	if not enabled:
		_clear_highlight()
		if ui != null and ui.has_method("hide_tutorial_text"):
			ui.hide_tutorial_text()
		return

	if manager != null:
		manager.next_tutorial_order = get_first_order_override()
	_show_current_step()


func get_first_order_override() -> Dictionary:
	return {
		"service_mode": "dine_in",
		"table_id": 1,
		"staple_type": "glass_noodle",
		"required_chili_count": 0
	}


func notify_event(event_name: String, payload: Dictionary = {}) -> void:
	if not enabled or finished:
		return
	if current_step_index < 0 or current_step_index >= steps.size():
		return

	var step: Dictionary = steps[current_step_index]
	var wait_type: String = str(step.get("wait_type", ""))
	if not _event_completes_wait(wait_type, event_name, payload):
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
			"text": "欢迎来到小猫麻辣烫连锁店培训！",
			"target_station": "",
			"wait_type": "confirm"
		},
		{
			"id": "intro_2",
			"text": "我们的店已经开到了很多地方，不过每家分店都会遇到不一样的麻烦。",
			"target_station": "",
			"wait_type": "confirm"
		},
		{
			"id": "intro_3",
			"text": "先从最基础的营业开始吧。让店铺恢复元气，大家就能拿到更多佣金！",
			"target_station": "",
			"wait_type": "confirm"
		},
		{
			"id": "wait_counter_order",
			"text": "顾客会自己选择配菜和饮料。等顾客来到收银台后，在收银台按 H 接单。",
			"target_station": "Counter",
			"wait_type": "counter_order_created"
		},
		{
			"id": "add_staple",
			"text": "你拿到了带小票的订单盆。先看订单栏：这单需要指定主食、四种基础小料，不需要辣椒。",
			"target_station": "StapleArea",
			"wait_type": "held_bowl_has_staple"
		},
		{
			"id": "put_in_pot",
			"text": "主食加好了。把订单盆放到操作台，或者直接拿去锅位，把食材倒进锅里。",
			"target_station": "CookerStation1",
			"wait_type": "bowl_in_pot"
		},
		{
			"id": "scoop_cooked_bowl",
			"text": "锅在锅位上才会加热。等它变成“已熟”后，用对应空碗盛出来。",
			"target_station": "CookerStation1",
			"wait_type": "held_bowl_cooked"
		},
		{
			"id": "mixed_sauces",
			"text": "现在去小料桶。每份麻辣烫都需要蒜水、麻酱、醋、糖各一次。",
			"target_station": "SauceStationMixed",
			"wait_type": "mixed_sauces_complete"
		},
		{
			"id": "deliver_table_1",
			"text": "这位顾客不要辣椒。把成品送到桌1。",
			"target_station": "DiningTable1",
			"wait_type": "dine_order_completed"
		},
		{
			"id": "first_order_done",
			"text": "店铺元气上升了！元气达标后，这家分店的问题就解决了。",
			"target_station": "",
			"wait_type": "confirm"
		}
	]


func _event_completes_wait(wait_type: String, event_name: String, payload: Dictionary) -> bool:
	match wait_type:
		"counter_order_created":
			return event_name == "counter_order_created"
		"held_bowl_has_staple":
			var bowl: OrderBowl = payload.get("bowl", null) as OrderBowl
			return event_name == "held_bowl_has_staple" and bowl != null and bowl.is_staple_ready_for_cooking()
		"bowl_in_pot":
			return event_name == "bowl_in_pot"
		"held_bowl_cooked":
			var cooked_bowl: OrderBowl = payload.get("bowl", null) as OrderBowl
			return event_name == "held_bowl_cooked" and cooked_bowl != null and cooked_bowl.status == OrderBowl.STATUS_COOKED
		"mixed_sauces_complete":
			var sauced_bowl: OrderBowl = payload.get("bowl", null) as OrderBowl
			return event_name == "sauce_changed" and sauced_bowl != null and sauced_bowl.has_all_required_mixed_sauces()
		"dine_order_completed":
			return event_name == "order_completed" and str(payload.get("service_mode", "")) == "dine_in"
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
	if ui != null and ui.has_method("show_tutorial_text"):
		ui.show_tutorial_text(str(step.get("text", "")))
	_set_target_station(str(step.get("target_station", "")))


func _finish_tutorial() -> void:
	finished = true
	enabled = false
	_clear_highlight()
	if ui != null and ui.has_method("show_tutorial_text"):
		ui.show_tutorial_text("第 1 份堂食教学完成。后续教学还在开发中。")


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
