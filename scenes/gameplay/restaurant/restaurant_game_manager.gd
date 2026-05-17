class_name RestaurantGameManager
extends Node

const RestaurantCustomerScene = preload("res://scenes/gameplay/restaurant/restaurant_customer.tscn")
const OrderBowlScene = preload("res://scenes/gameplay/restaurant/order_bowl.tscn")
const ItemIds = preload("res://gameplay/models/item_ids.gd")
const NIGHT_SUMMARY_SCENE_PATH = "res://scenes/restaurant_summary/restaurant_night_summary.tscn"

@export var max_customers: int = 3
@export var customer_count_min: int = 0
@export var customer_count_max: int = 0
@export var spawn_interval_seconds: float = 6.0
@export var day_time_seconds: float = 90.0
@export var auto_change_to_summary: bool = true

var queued_customers: Array[RestaurantCustomer] = []
var waiting_customers_by_order_id: Dictionary = {}
var completed_orders: int = 0
var failed_orders: int = 0
var money_today: int = 0
var score_today: int = 0
var queue_lost_customers_today: int = 0
var current_day: int = 1
var max_days: int = 3
var day_time_remaining: float = 90.0
var is_day_open: bool = true
var is_ending_day: bool = false
var summary_transition_requested: bool = false
var next_order_id: int = 1
var spawn_count: int = 0
var planned_customer_count: int = 3
var spawn_elapsed: float = 0.0
var tutorial_controller: TutorialController = null
var next_tutorial_order: Dictionary = {}
var tutorial_refill_holder_by_order_id: Dictionary = {}
var dirty_dining_tables: Dictionary = {}
var held_table_trash: int = 0
var busy_action_name: String = ""
var busy_action_remaining: float = 0.0
var busy_action_callback: Callable = Callable()

var held_bowl: OrderBowl = null
var held_pot: CookingPot = null
var held_dirty_cooker: CookerStation = null
var held_dirty_pot_visual: Node2D = null
@onready var characters_node: Node2D = $"../Characters"
@onready var bowls_node: Node2D = $"../Bowls"
@onready var entrance: Marker2D = $"../Markers/Entrance"
@onready var ingredient_display: Marker2D = $"../Markers/IngredientDisplay"
@onready var counter_spot: Marker2D = $"../Markers/CounterSpot"
@onready var exit_point: Marker2D = $"../Markers/Exit"
@onready var takeout_wait: Marker2D = $"../Markers/TakeoutWait"
@onready var takeout_pickup: Marker2D = $"../Markers/TakeoutPickup"
@onready var queue_spots_parent: Node2D = $"../Markers/QueueSpots"
@onready var table_spots_parent: Node2D = $"../Markers/TableSpots"
@onready var waiting_area: WaitingOrderArea = $"../Stations/WaitingOrderArea"
@onready var cooker_1: CookerStation = $"../Stations/CookerStations/CookerStation1"
@onready var cooker_2: CookerStation = $"../Stations/CookerStations/CookerStation2"
@onready var surface_slots_parent: Node = $"../SurfaceSlots"
@onready var ui: RestaurantUI = $"../UI"

var surface_slots_by_id: Dictionary = {}


func _ready() -> void:
	add_to_group("restaurant_game_manager")
	randomize()
	_cache_surface_slots()
	_initialize_day_state()
	tutorial_controller = get_node_or_null("../TutorialController") as TutorialController
	if tutorial_controller != null:
		tutorial_controller.setup(self, ui)
	_resolve_planned_customer_count()
	if is_day_open and not _is_tutorial_customer_controlled():
		spawn_customer()
	_refresh_ui("餐厅营业开始")


func _initialize_day_state() -> void:
	current_day = int(RestaurantRunState.current_day)
	max_days = int(RestaurantRunState.max_days)
	day_time_remaining = day_time_seconds
	is_day_open = day_time_remaining > 0.0
	is_ending_day = false
	summary_transition_requested = false
	completed_orders = 0
	failed_orders = 0
	money_today = 0
	score_today = 0
	queue_lost_customers_today = 0
	spawn_count = 0
	planned_customer_count = max(0, max_customers)


func _notify_tutorial(event_name: String, payload: Dictionary = {}) -> void:
	if tutorial_controller == null:
		return
	tutorial_controller.notify_event(event_name, payload)


func _is_tutorial_customer_controlled() -> bool:
	return tutorial_controller != null and tutorial_controller.has_method("controls_customer_spawning") and tutorial_controller.controls_customer_spawning()


func _is_tutorial_time_paused() -> bool:
	return tutorial_controller != null and tutorial_controller.has_method("pauses_time") and tutorial_controller.pauses_time()


func _is_tutorial_cooked_pot_protected(bowl: OrderBowl = null) -> bool:
	if tutorial_controller == null:
		return false
	if bowl != null and tutorial_controller.has_method("protects_cooked_pot_for_bowl"):
		return tutorial_controller.protects_cooked_pot_for_bowl(bowl)
	return tutorial_controller.has_method("protects_cooked_pots") and tutorial_controller.protects_cooked_pots()


func _resolve_planned_customer_count() -> void:
	if tutorial_controller != null and tutorial_controller.has_method("get_planned_customer_count"):
		var tutorial_customer_count: int = int(tutorial_controller.get_planned_customer_count())
		if tutorial_customer_count > 0:
			planned_customer_count = tutorial_customer_count
			return
	var min_count: int = int(customer_count_min)
	var max_count: int = int(customer_count_max)
	if min_count <= 0 and max_count <= 0:
		planned_customer_count = max(0, int(max_customers))
		return
	min_count = max(0, min_count)
	max_count = max(min_count, max_count)
	planned_customer_count = randi_range(min_count, max_count)


func _has_any_held_item() -> bool:
	return held_bowl != null or held_pot != null or held_dirty_cooker != null or int(held_table_trash) != 0


func _is_busy() -> bool:
	return busy_action_remaining > 0.0


func is_busy_action_active() -> bool:
	return _is_busy()


func _busy_status_text() -> String:
	if busy_action_name.strip_edges() == "":
		return "处理中"
	return "处理中：%s" % busy_action_name


func _begin_busy_action(action_name: String, duration: float, callback: Callable) -> void:
	busy_action_name = action_name
	busy_action_remaining = max(duration, 0.0)
	busy_action_callback = callback
	_refresh_ui(_busy_status_text())


func _update_busy_action(delta: float) -> void:
	if busy_action_remaining <= 0.0:
		return
	busy_action_remaining = max(busy_action_remaining - delta, 0.0)
	if busy_action_remaining > 0.0:
		_refresh_ui(_busy_status_text())
		return
	var callback: Callable = busy_action_callback
	busy_action_name = ""
	busy_action_callback = Callable()
	if callback.is_valid():
		callback.call()


func notify_tutorial_bowl_became_cooked(bowl: OrderBowl) -> void:
	_notify_tutorial("tutorial_bowl_became_cooked", {"bowl": bowl})


func _update_day_timer(delta: float) -> void:
	if not is_day_open:
		return
	day_time_remaining = max(day_time_remaining - delta, 0.0)
	if day_time_remaining <= 0.0:
		is_day_open = false
		spawn_elapsed = 0.0


func _process(delta: float) -> void:
	_update_busy_action(delta)
	var tutorial_time_paused: bool = _is_tutorial_time_paused()
	var tutorial_customer_controlled: bool = _is_tutorial_customer_controlled()
	if not tutorial_time_paused:
		_update_day_timer(delta)
		if is_day_open and not tutorial_customer_controlled:
			spawn_elapsed += delta
		if is_day_open and not tutorial_customer_controlled and spawn_count < planned_customer_count and spawn_elapsed >= spawn_interval_seconds:
			spawn_elapsed = 0.0
			spawn_customer()
		_update_order_patience(delta)
		_handle_queue_patience_failures()
	_update_score()
	if not tutorial_time_paused:
		_check_day_end()
	_refresh_ui()


func spawn_customer() -> RestaurantCustomer:
	if not is_day_open or spawn_count >= planned_customer_count:
		return null

	var customer: RestaurantCustomer = RestaurantCustomerScene.instantiate() as RestaurantCustomer
	characters_node.add_child(customer)
	customer.setup(self, entrance.global_position, ingredient_display.global_position)
	spawn_count += 1
	return customer


func request_close_day() -> void:
	if is_ending_day:
		_refresh_ui("正在进入结算")
		if ui != null and ui.has_method("show_toast"):
			ui.show_toast("正在进入结算", 1.8)
		return
	is_day_open = false
	day_time_remaining = 0.0
	spawn_elapsed = 0.0
	_refresh_ui("已打烊：不会再来新顾客，请处理剩余订单")
	if ui != null and ui.has_method("show_toast"):
		ui.show_toast("已打烊：不会再来新顾客", 1.8)
	_check_day_end()


func enqueue_customer(customer: RestaurantCustomer) -> void:
	if customer == null or queued_customers.has(customer):
		return
	queued_customers.append(customer)
	refresh_queue_positions()


func refresh_queue_positions() -> void:
	for i in range(queued_customers.size()):
		var customer: RestaurantCustomer = queued_customers[i]
		if customer == null or not is_instance_valid(customer):
			continue
		if i == 0:
			customer.move_to_counter(counter_spot.global_position)
		else:
			var queue_spot: Vector2 = _get_queue_spot(i - 1)
			customer.move_to_queue(queue_spot, i)


func interact_with_station(station_name: String) -> void:
	interact_with_station_action(station_name, "interact")


func interact_with_station_action(station_name: String, action_name: String = "interact") -> void:
	if _is_busy():
		_refresh_ui(_busy_status_text())
		return
	if station_name == "SauceStation":
		interact_chili_station_action(action_name)
		return
	if station_name == "SauceStationMixed":
		interact_sauce_station_action(action_name)
		return
	if station_name == "IngredientDisplay" or station_name == "IngredientDisplay2" or station_name == "IngredientDisplay3":
		interact_ingredient_display()
		return
	if station_name == "CustomerTrashBin" and (action_name == "interact" or action_name == "sauce_x"):
		interact_customer_trash_bin()
		return
	if action_name != "interact" and action_name != "sauce_x":
		return

	if station_name.begins_with("SurfaceSlot_") or station_name.begins_with("TakeoutPickupSlot"):
		interact_surface_slot(station_name)
		return

	match station_name:
		"Counter":
			interact_counter()
		"WaitingOrderArea":
			interact_waiting_order_area()
		"CookerStation1":
			interact_cooker(cooker_1)
		"CookerStation2":
			interact_cooker(cooker_2)
		"StapleArea", "StapleCabinet":
			interact_staple_cabinet()
		"PackingArea":
			interact_packing_area()
		"PackingBagArea":
			interact_packing_bag_area()
		"DiningTable1":
			interact_delivery_table(1)
		"DiningTable2":
			interact_delivery_table(2)
		"DiningTable3":
			_interact_placeholder(station_name)
		"TakeoutPickup":
			interact_takeout_pickup()
		"TrashBin":
			interact_trash_bin()
		"IngredientDisplayLocked", "DrinksFridge", "DrinkFridgeLocked", "StorageArea", "DrinkStorage", "CookerStationLocked":
			_interact_placeholder(station_name)
		_:
			_refresh_ui("这里暂时不能操作：%s" % station_name)


func _get_tutorial_submission_block_message(bowl: OrderBowl) -> String:
	if tutorial_controller == null:
		return ""
	if not tutorial_controller.has_method("get_order_submission_block_message"):
		return ""
	return str(tutorial_controller.get_order_submission_block_message(bowl))


func _interact_placeholder(station_name: String) -> void:
	var message: String = "占位功能：%s" % station_name
	match station_name:
		"IngredientDisplay", "IngredientDisplay2", "IngredientDisplay3":
			message = "顾客会在这里选菜"
		"IngredientDisplayLocked":
			message = "这个选菜格还未解锁"
		"DrinksFridge":
			message = "饮料流程暂未开放"
		"DrinkFridgeLocked":
			message = "饮料格还未解锁"
		"PackingBagArea":
			message = "袋子区占位，暂未开放"
		"SauceStationMixed":
			message = "小料组合操作暂未开放"
		"CustomerTrashBin":
			message = "垃圾桶占位"
		"StorageArea":
			message = "补货流程暂未开放"
		"DrinkStorage":
			message = "饮料库存占位"
		"CookerStationLocked":
			message = "锅位还未解锁"
		"DiningTable3":
			message = "本关暂不使用桌3"
	_refresh_ui(message)
	if ui != null and ui.has_method("show_toast"):
		ui.show_toast(message, 1.4)


func interact_ingredient_display() -> void:
	if held_dirty_cooker != null:
		_refresh_ui("先清理脏锅")
		return
	if held_pot != null:
		_refresh_ui("先放下锅")
		return
	if held_bowl == null:
		_refresh_ui("先拿着需要补配的空盆")
		return
	if not held_bowl.needs_refill:
		_refresh_ui("这只盆不需要补配")
		return
	var refill_order_id: int = held_bowl.order_id
	held_bowl.refill_from_ticket()
	tutorial_refill_holder_by_order_id.erase(refill_order_id)
	_refresh_ui("已按小票补回配菜，请重新加入主食")
	_notify_tutorial("bowl_refilled", {"bowl": held_bowl})


func interact_counter() -> void:
	if _is_busy():
		_refresh_ui(_busy_status_text())
		return
	if held_table_trash != 0:
		_refresh_ui("先把手里的垃圾扔掉")
		return
	if held_dirty_cooker != null:
		_refresh_ui("先清理脏锅")
		return
	if held_pot != null:
		_refresh_ui("先放下锅")
		return
	var customer: RestaurantCustomer = _get_counter_customer()
	if held_bowl != null:
		if customer != null:
			_refresh_ui("先放下手里的东西")
		else:
			interact_takeout_counter_delivery()
		return
	if customer == null:
		_refresh_ui("收银台前没有顾客")
		return

	_begin_busy_action("收银", 0.6, Callable(self, "_finish_counter_busy").bind(customer))


func _finish_counter_busy(customer: RestaurantCustomer) -> void:
	if customer == null or not is_instance_valid(customer):
		_refresh_ui("收银台前没有顾客")
		return
	_create_order_from_customer(customer)


func _create_order_from_customer(customer: RestaurantCustomer) -> void:
	if customer == null:
		return
	if _has_any_held_item():
		_refresh_ui("先放下手里的东西")
		return

	var ingredients: Dictionary = customer.get_bowl_ingredients()
	if ingredients.is_empty():
		_refresh_ui("顾客还没有选菜")
		return

	var bowl: OrderBowl = OrderBowlScene.instantiate() as OrderBowl
	var order_id: int = next_order_id
	next_order_id += 1
	var staple_type: String = _random_staple()
	var required_chili_count: int = _random_chili_count()
	var spice_level: String = _spice_level_from_chili_count(required_chili_count)
	var service_mode: String = _random_service_mode()
	var table_id: int = _next_table_id() if service_mode == "dine_in" else 0
	if not next_tutorial_order.is_empty():
		staple_type = str(next_tutorial_order.get("staple_type", staple_type))
		required_chili_count = int(next_tutorial_order.get("required_chili_count", required_chili_count))
		spice_level = _spice_level_from_chili_count(required_chili_count)
		service_mode = str(next_tutorial_order.get("service_mode", service_mode))
		table_id = int(next_tutorial_order.get("table_id", table_id)) if service_mode == "dine_in" else 0
		next_tutorial_order.clear()

	bowl.setup_order(
		order_id,
		ingredients,
		staple_type,
		spice_level,
		service_mode,
		table_id,
		required_chili_count
	)

	_hold_bowl(bowl)

	queued_customers.erase(customer)
	waiting_customers_by_order_id[order_id] = customer
	var wait_position: Vector2 = takeout_wait.global_position
	if service_mode == "dine_in":
		wait_position = _get_table_spot(table_id)
	customer.wait_for_order(order_id, service_mode, table_id, wait_position)

	_refresh_ui("订单 #%03d 已生成：%s / %s / %s" % [
		order_id,
		_staple_text(staple_type),
		"辣椒%d下" % required_chili_count,
		_service_text(service_mode, table_id)
	])
	refresh_queue_positions()
	_notify_tutorial("counter_order_created", {"bowl": held_bowl})


func interact_waiting_order_area() -> void:
	if held_dirty_cooker != null:
		_refresh_ui("先清理脏锅")
		return
	if held_pot != null:
		_refresh_ui("先放下锅")
		return

	if held_bowl == null:
		var bowl: OrderBowl = waiting_area.take_first_bowl()
		if bowl == null:
			_refresh_ui("待煮区是空的")
			return
		_hold_bowl(bowl)
		_refresh_ui("拿起%s" % bowl.get_summary_text())
		return

	if held_bowl.status == OrderBowl.STATUS_WAITING:
		if waiting_area.add_bowl(held_bowl):
			held_bowl = null
			_refresh_ui("已放回待煮区")
		else:
			_refresh_ui("待煮区满了")
	else:
		_refresh_ui("这个碗应该继续往后处理，不能放回待煮区")


func _can_add_order_bowl_to_pot(order_bowl: OrderBowl, pot: CookingPot) -> bool:
	if order_bowl == null or pot == null:
		return false
	if order_bowl.is_empty_holder:
		_refresh_ui("这是空碗，不能倒入锅")
		return false
	if order_bowl.status != OrderBowl.STATUS_WAITING:
		_refresh_ui("这个碗不能放入锅")
		return false
	if not order_bowl.is_staple_ready_for_cooking():
		_refresh_ui("请先加主食")
		return false
	if not pot.is_empty():
		_refresh_ui("锅里已经有东西")
		return false
	return true


func interact_surface_slot(slot_id: String) -> void:
	if held_table_trash != 0:
		_refresh_ui("手里有东西，先放下再拿")
		return
	if held_dirty_cooker != null:
		_refresh_ui("先清理脏锅")
		return

	var slot: SurfaceSlot = _get_surface_slot(slot_id)
	if slot == null:
		_refresh_ui("找不到这个桌面")
		return

	if held_pot != null:
		var slot_bowl: OrderBowl = slot.get_stored_bowl()
		if slot_bowl != null and held_pot.can_scoop_to_empty_bowl(slot_bowl):
			held_pot.scoop_to_empty_bowl(slot_bowl)
			slot.refresh_visual()
			_refresh_ui("已盛出订单 #%03d" % slot_bowl.order_id)
			_notify_tutorial("held_bowl_cooked", {"bowl": slot_bowl})
			return
		if slot_bowl != null:
			if _can_add_order_bowl_to_pot(slot_bowl, held_pot):
				var order_bowl: OrderBowl = slot_bowl
				var empty_holder: OrderBowl = _create_empty_holder_for_order(order_bowl)
				var removed_item: Node2D = slot.take_item()
				if removed_item != order_bowl:
					_refresh_ui("桌面状态异常")
					if empty_holder != null:
						empty_holder.queue_free()
					return
				if held_pot.add_order_bowl(order_bowl):
					if not slot.store_bowl(empty_holder):
						empty_holder.queue_free()
						_refresh_ui("无法放下空碗")
						return
					slot.refresh_visual()
					_refresh_ui("已把订单 #%03d 放入锅中" % order_bowl.order_id)
					_notify_tutorial("bowl_in_pot", {"bowl": order_bowl})
				else:
					slot.store_bowl(order_bowl)
					empty_holder.queue_free()
					_refresh_ui("无法把订单放入锅")
				return
			return
		if not slot.is_empty():
			_refresh_ui("这个桌面已经被占用")
			return
		var placed_pot: CookingPot = held_pot
		if not slot.store_item(placed_pot):
			_refresh_ui("无法放下锅")
			return
		held_pot = null
		_refresh_ui("已把锅放到 %s" % slot.slot_label)
		return

	if held_bowl != null:
		var slot_pot: CookingPot = slot.get_stored_pot()
		if slot_pot != null and slot_pot.can_scoop_to_empty_bowl(held_bowl):
			slot_pot.scoop_to_empty_bowl(held_bowl)
			slot.refresh_visual()
			_refresh_ui("已盛出订单 #%03d" % held_bowl.order_id)
			_notify_tutorial("held_bowl_cooked", {"bowl": held_bowl})
			return
		if slot_pot != null:
			if _can_add_order_bowl_to_pot(held_bowl, slot_pot):
				var order_bowl: OrderBowl = held_bowl
				var empty_holder: OrderBowl = _create_empty_holder_for_order(order_bowl)
				if slot_pot.add_order_bowl(order_bowl):
					held_bowl = empty_holder
					_hold_bowl(held_bowl)
					slot.refresh_visual()
					_refresh_ui("已把订单 #%03d 放入锅中" % order_bowl.order_id)
					_notify_tutorial("bowl_in_pot", {"bowl": order_bowl})
				else:
					empty_holder.queue_free()
					_refresh_ui("无法把订单放入锅")
				return
			return
		if not slot.is_empty():
			_refresh_ui("这个桌面已经被占用")
			return
		var placed_bowl: OrderBowl = held_bowl
		if not slot.store_bowl(placed_bowl):
			_refresh_ui("无法放下碗")
			return
		held_bowl = null
		if _try_complete_takeout_from_surface(slot, placed_bowl):
			return
		if slot.is_takeout_pickup_slot and placed_bowl.service_mode == "takeout":
			if placed_bowl.status == OrderBowl.STATUS_SEALED:
				_refresh_ui("外带单还没有装袋")
				return
			if placed_bowl.status != OrderBowl.STATUS_PACKED:
				_refresh_ui("外带单还没有封口")
				return
		_refresh_ui("已把订单 #%03d 放到 %s" % [placed_bowl.order_id, slot.slot_label])
		return

	var item: Node2D = slot.take_item()
	if item == null:
		_refresh_ui("桌上是空的")
		return
	var pot: CookingPot = item as CookingPot
	if pot != null:
		_hold_pot(pot)
		_refresh_ui("拿起锅")
		return
	var bowl: OrderBowl = item as OrderBowl
	if bowl == null:
		_refresh_ui("桌上的东西不能拿起")
		return
	_hold_bowl(bowl)
	if bowl.needs_refill:
		_refresh_ui("拿起待补配订单盆 #%03d" % bowl.order_id)
		_notify_tutorial("refill_bowl_picked_up", {"bowl": bowl})
		return
	_refresh_ui("拿起空碗 #%03d" % bowl.order_id if bowl.is_empty_holder else "拿起订单 #%03d" % bowl.order_id)


func interact_cooker(cooker: CookerStation) -> void:
	if cooker == null:
		return

	if held_table_trash != 0:
		_refresh_ui("手里有东西，先放下再拿锅")
		return

	if held_dirty_cooker != null:
		_refresh_ui("先清理脏锅")
		return

	if held_pot != null:
		if cooker.has_pot():
			_refresh_ui("这个锅位已经有锅")
			return
		var placed_pot: CookingPot = held_pot
		if cooker.place_pot(held_pot):
			held_pot = null
			_notify_tutorial("pot_placed_on_cooker", {"cooker": cooker, "pot": placed_pot})
			_refresh_ui("锅已放回锅位")
		else:
			_refresh_ui("无法放下锅")
		return

	if held_bowl != null:
		if held_bowl.is_empty_holder:
			if _try_take_overcooked_pot_from_cooker(cooker):
				return
			if cooker.scoop_to_bowl(held_bowl):
				_refresh_ui("已盛出订单 #%03d" % held_bowl.order_id)
				_notify_tutorial("held_bowl_cooked", {"bowl": held_bowl})
			else:
				_refresh_ui("锅里没有可盛出的熟食")
			return
		if not cooker.has_pot():
			_refresh_ui("锅位上没有锅")
			return
		if not _can_add_order_bowl_to_pot(held_bowl, cooker.active_pot):
			return
		var order_bowl: OrderBowl = held_bowl
		if cooker.add_bowl_to_pot(order_bowl):
			held_bowl = _create_empty_holder_for_order(order_bowl)
			_hold_bowl(held_bowl)
			_refresh_ui("已把订单 #%03d 放入锅中" % order_bowl.order_id)
			_notify_tutorial("bowl_in_pot", {"bowl": order_bowl})
		else:
			_refresh_ui("锅里已经有东西")
		return

	var pot: CookingPot = cooker.take_pot()
	if pot == null:
		_refresh_ui("锅位上没有锅")
		return
	_hold_pot(pot)
	if pot.has_overcooked_content():
		_notify_tutorial("overcooked_pot_picked_up", {"order_id": pot.content_bowl.order_id})
	_refresh_ui("拿起锅")


func _try_take_overcooked_pot_from_cooker(cooker: CookerStation) -> bool:
	if cooker == null or not cooker.has_pot() or not cooker.active_pot.has_overcooked_content():
		return false
	var active_order_id: int = cooker.active_pot.content_bowl.order_id
	if _has_any_held_item():
		_refresh_ui("手里有东西，先放下再拿锅")
		return true
	if not tutorial_refill_holder_by_order_id.has(active_order_id):
		var existing_holder: OrderBowl = _find_existing_empty_holder_for_order(active_order_id)
		if existing_holder != null:
			tutorial_refill_holder_by_order_id[active_order_id] = existing_holder
	var pot: CookingPot = cooker.take_pot()
	if pot == null:
		return false
	_hold_pot(pot)
	_refresh_ui("拿起煮糊的锅")
	_notify_tutorial("overcooked_pot_picked_up", {"order_id": active_order_id})
	return true


func interact_staple_cabinet() -> void:
	if held_dirty_cooker != null:
		_refresh_ui("先清理脏锅")
		return
	if held_pot != null:
		_refresh_ui("先放下锅")
		return
	if held_bowl == null:
		_refresh_ui("先拿着订单碗")
		return
	if held_bowl.is_empty_holder and not held_bowl.needs_refill:
		_refresh_ui("空碗不需要加主食")
		return
	if held_bowl.status != OrderBowl.STATUS_WAITING:
		_refresh_ui("只有待处理订单需要加主食")
		return
	if held_bowl.staple_type == "none":
		held_bowl.staple_added = true
		held_bowl.actual_staple_type = "none"
		held_bowl.refresh_visuals()
		_refresh_ui("这单不需要主食")
		_notify_tutorial("held_bowl_has_staple", {"bowl": held_bowl})
		return
	if held_bowl.staple_added:
		_refresh_ui("主食已经加过了")
		return

	held_bowl.add_required_staple()
	_refresh_ui("已加入主食：%s" % _staple_text(held_bowl.staple_type))
	_notify_tutorial("held_bowl_has_staple", {"bowl": held_bowl})


func interact_sauce_station() -> void:
	interact_sauce_station_action("interact")


func interact_sauce_station_action(action_name: String = "interact") -> void:
	if held_dirty_cooker != null:
		_refresh_ui("先清理脏锅")
		return
	if held_pot != null:
		_refresh_ui("先放下锅")
		return
	if held_bowl == null:
		_refresh_ui("先拿着煮好的碗")
		return
	if _reject_overcooked_held_order():
		return
	if held_bowl.status != OrderBowl.STATUS_COOKED and held_bowl.status != OrderBowl.STATUS_SAUCED:
		_refresh_ui("煮熟后才能加小料")
		return
	var sauce_id: String = _sauce_id_for_action(action_name)
	var sauce_name: String = _sauce_display_text(sauce_id)
	if held_bowl.has_mixed_sauce(sauce_id):
		_refresh_ui("已经加过：%s" % sauce_name)
		return
	if not held_bowl.add_mixed_sauce_once(sauce_id):
		return
	var mixed_sauce_count: int = held_bowl.get_mixed_sauce_count()
	_refresh_ui("已加小料：%s（%d/4）" % [sauce_name, mixed_sauce_count])
	_notify_tutorial("sauce_changed", {"bowl": held_bowl})


func interact_chili_station_action(action_name: String = "interact") -> void:
	if held_dirty_cooker != null:
		_refresh_ui("先清理脏锅")
		return
	if held_pot != null:
		_refresh_ui("先放下锅")
		return
	if held_bowl == null:
		_refresh_ui("先拿着煮好的碗")
		return
	if _reject_overcooked_held_order():
		return
	if held_bowl.status != OrderBowl.STATUS_COOKED and held_bowl.status != OrderBowl.STATUS_SAUCED:
		_refresh_ui("煮熟后才能加小料")
		return
	if action_name == "sauce_y" or action_name == "sauce_a" or action_name == "sauce_b":
		_refresh_ui("这个辣椒格位置暂未开放")
		return
	if held_bowl.required_chili_count <= 0:
		_refresh_ui("这单不要辣椒")
		return
	if held_bowl.added_chili_count >= held_bowl.required_chili_count:
		_refresh_ui("辣椒已经够了")
		return
	if held_bowl.add_chili_once():
		_refresh_ui("已加辣椒：%d/%d" % [held_bowl.added_chili_count, held_bowl.required_chili_count])
		_notify_tutorial("chili_changed", {"bowl": held_bowl})


func _check_sauce_complete_for_current_bowl(action_text: String) -> bool:
	if held_bowl == null:
		return false
	if not held_bowl.has_all_required_mixed_sauces():
		_refresh_ui("%s前还缺必加小料：小料%d/4" % [action_text, held_bowl.get_mixed_sauce_count()])
		return false
	if not held_bowl.has_exact_chili():
		if held_bowl.added_chili_count < held_bowl.required_chili_count:
			_refresh_ui("%s前辣椒还不够：%d/%d" % [action_text, held_bowl.added_chili_count, held_bowl.required_chili_count])
		else:
			_refresh_ui("%s前辣椒数量不对：%d/%d" % [action_text, held_bowl.added_chili_count, held_bowl.required_chili_count])
		return false
	return true


func interact_packing_area() -> void:
	if _is_busy():
		_refresh_ui(_busy_status_text())
		return
	if held_dirty_cooker != null:
		_refresh_ui("先清理脏锅")
		return
	if held_pot != null:
		_refresh_ui("先放下锅")
		return
	if held_bowl == null:
		_refresh_ui("先拿着外带碗")
		return
	if _reject_overcooked_held_order():
		return
	if held_bowl.service_mode != "takeout":
		_refresh_ui("堂食订单要送到桌子")
		return
	if held_bowl.status == OrderBowl.STATUS_PACKED:
		_refresh_ui("订单已经装袋，请放到外带桌")
		return
	if held_bowl.status == OrderBowl.STATUS_SEALED:
		_refresh_ui("已经封口，请去袋子区装袋")
		return
	_begin_busy_action("封口中", 0.8, Callable(self, "_finish_packing_area_busy").bind(held_bowl))


func _finish_packing_area_busy(target_bowl: OrderBowl) -> void:
	if target_bowl == null or not is_instance_valid(target_bowl) or held_bowl != target_bowl:
		_refresh_ui("封口中断，请重新操作")
		return
	if target_bowl.service_mode != "takeout" or target_bowl.status == OrderBowl.STATUS_SEALED or target_bowl.status == OrderBowl.STATUS_PACKED:
		_refresh_ui("这份外带单现在不能封口")
		return
	target_bowl.mark_sealed()
	_notify_tutorial("takeout_order_sealed", {"bowl": target_bowl})
	var quality: Dictionary = _evaluate_order_quality(target_bowl)
	if int(quality.get("money", 0)) == 10 and int(quality.get("score", 0)) == 0:
		_refresh_ui("订单 #%03d 已封口，请去袋子区装袋" % target_bowl.order_id)
	else:
		_refresh_ui("订单 #%03d 已封口，但质量有问题" % target_bowl.order_id)


func interact_packing_bag_area() -> void:
	if _is_busy():
		_refresh_ui(_busy_status_text())
		return
	if held_dirty_cooker != null:
		_refresh_ui("先清理脏锅")
		return
	if held_pot != null:
		_refresh_ui("先放下锅")
		return
	if held_bowl == null:
		_refresh_ui("先拿着已封口的外带碗")
		return
	if _reject_overcooked_held_order():
		return
	if held_bowl.service_mode != "takeout":
		_refresh_ui("堂食订单不用装袋")
		return
	if held_bowl.status == OrderBowl.STATUS_PACKED:
		_refresh_ui("订单已经装袋，请放到外带桌")
		return
	if held_bowl.status != OrderBowl.STATUS_SEALED:
		_refresh_ui("请先去封口机打包")
		return
	_begin_busy_action("装袋中", 0.5, Callable(self, "_finish_packing_bag_busy").bind(held_bowl))


func _finish_packing_bag_busy(target_bowl: OrderBowl) -> void:
	if target_bowl == null or not is_instance_valid(target_bowl) or held_bowl != target_bowl:
		_refresh_ui("装袋中断，请重新操作")
		return
	if target_bowl.service_mode != "takeout" or target_bowl.status != OrderBowl.STATUS_SEALED:
		_refresh_ui("这份外带单现在不能装袋")
		return
	target_bowl.mark_packed()
	_notify_tutorial("takeout_order_packed", {"bowl": target_bowl})
	_refresh_ui("订单 #%03d 已装袋，请放到外带桌" % target_bowl.order_id)


func interact_delivery_table(table_id: int) -> void:
	if held_table_trash != 0:
		_refresh_ui("先把手里的垃圾扔掉")
		return
	if held_dirty_cooker != null:
		_refresh_ui("先清理脏锅")
		return
	if held_pot != null:
		_refresh_ui("先放下锅")
		return
	if held_bowl == null:
		if bool(dirty_dining_tables.get(table_id, false)):
			dirty_dining_tables.erase(table_id)
			held_table_trash = table_id
			_refresh_dining_table_visual(table_id)
			_refresh_ui("收起桌%d的垃圾，请拿去垃圾桶" % table_id)
			_notify_tutorial("table_trash_picked_up", {"table_id": table_id})
		else:
			_refresh_ui("这张桌子现在不需要收拾")
		return
	if _reject_overcooked_held_order():
		return
	if held_bowl.service_mode != "dine_in" or held_bowl.table_id != table_id:
		_refresh_ui("不是这张桌")
		return
	if held_bowl.is_empty_holder:
		_refresh_ui("堂食不能出空碗")
		return
	if not held_bowl.has_food_content_for_serving():
		_refresh_ui("堂食餐品还不能出餐")
		return
	if not held_bowl.has_correct_staple():
		_refresh_ui("堂食主食不对，不能出餐")
		return
	_complete_held_order()


func interact_customer_trash_bin() -> void:
	if held_table_trash == 0:
		_refresh_ui("没有要扔的桌面垃圾")
		return
	var table_id: int = held_table_trash
	held_table_trash = 0
	_refresh_ui("已扔掉桌%d的垃圾" % table_id)
	_notify_tutorial("table_trash_discarded", {"table_id": table_id})


func interact_takeout_pickup() -> void:
	if held_dirty_cooker != null:
		_refresh_ui("先清理脏锅")
		return
	if held_pot != null:
		_refresh_ui("打包好的外带碗请放到外带桌1或外带桌2")
		return
	if held_bowl == null:
		_refresh_ui("先拿着已打包外带碗")
		return
	if _reject_overcooked_held_order():
		return
	if held_bowl.service_mode != "takeout":
		_refresh_ui("堂食订单要送到对应桌子")
		return
	if held_bowl.status == OrderBowl.STATUS_SEALED:
		_refresh_ui("外带单还没有装袋")
		return
	if held_bowl.status != OrderBowl.STATUS_PACKED:
		_refresh_ui("外带单还没有封口")
		return
	_refresh_ui("请使用外带桌1或外带桌2")


func interact_takeout_counter_delivery() -> void:
	if held_bowl == null:
		return
	if _reject_overcooked_held_order():
		return
	if held_bowl.service_mode != "takeout":
		_refresh_ui("堂食订单要送到对应桌子")
		return
	if held_bowl.status == OrderBowl.STATUS_SEALED:
		_refresh_ui("外带单还没有装袋")
		return
	if held_bowl.status != OrderBowl.STATUS_PACKED:
		_refresh_ui("外带单还没有封口")
		return
	_complete_held_order()


func interact_trash_bin() -> void:
	if held_pot != null:
		if held_pot.has_overcooked_content():
			var cleared_bowl: OrderBowl = held_pot.clear_content()
			var cleared_order_id: int = 0
			if cleared_bowl != null:
				cleared_order_id = cleared_bowl.order_id
				var original_holder: OrderBowl = _find_original_holder_for_refill(cleared_order_id)
				if original_holder != null and is_instance_valid(original_holder):
					tutorial_refill_holder_by_order_id[cleared_order_id] = original_holder
					original_holder.mark_needs_refill()
					_refresh_surface_slot_containing_bowl(original_holder)
					if cleared_bowl != original_holder:
						cleared_bowl.queue_free()
				else:
					push_warning("Overcooked order refill holder was not found; no new bowl will be created.")
					cleared_bowl.queue_free()
			held_pot.refresh_visual()
			_notify_tutorial("overcooked_pot_cleared", {"order_id": cleared_order_id})
			if cleared_order_id > 0:
				var refill_holder: OrderBowl = _find_original_holder_for_refill(cleared_order_id)
				if refill_holder != null and is_instance_valid(refill_holder) and refill_holder.needs_refill:
					_notify_tutorial("tutorial_overcook_cleared", {"bowl": refill_holder})
					_refresh_ui("食物倒掉了。先把空锅放回锅位，再拿起待补配订单盆。")
				else:
					_refresh_ui("食物已倒掉，但没有找到原订单盆，请找回订单盆继续补单。")
			else:
				_refresh_ui("锅已清空")
			return
		if held_pot.is_empty():
			_refresh_ui("锅是空的")
		else:
			_refresh_ui("只有煮糊的锅可以倒掉")
		return

	if held_dirty_cooker != null:
		_clear_held_dirty_cooker()
		return

	if held_bowl == null:
		_refresh_ui("没有可以丢弃的东西")
		return
	if held_bowl.is_empty_holder:
		if _has_active_content_for_order(held_bowl.order_id):
			_refresh_ui("这只空碗还要用来盛出锅里的食材")
			return
		_refresh_ui("订单盆不能扔垃圾桶")
		return
	_refresh_ui("订单盆不能扔垃圾桶")


func _is_tutorial_forced_overcook_order(order_id: int) -> bool:
	if tutorial_controller == null or order_id <= 0:
		return false
	if not tutorial_controller.has_method("is_forced_overcook_order"):
		return false
	return bool(tutorial_controller.is_forced_overcook_order(order_id))


func _find_original_holder_for_refill(order_id: int) -> OrderBowl:
	if order_id <= 0:
		return null
	var cached_holder: OrderBowl = tutorial_refill_holder_by_order_id.get(order_id, null) as OrderBowl
	if cached_holder != null and is_instance_valid(cached_holder) and cached_holder.order_id == order_id and cached_holder.is_empty_holder:
		return cached_holder
	return _find_existing_empty_holder_for_order(order_id)


func _place_tutorial_refill_bowl(bowl: OrderBowl) -> bool:
	if bowl == null:
		return false
	_cache_surface_slots()
	var target_slot: SurfaceSlot = _get_surface_slot("SurfaceSlot_r1c8")
	if target_slot == null or not target_slot.is_empty():
		target_slot = null
		for slot_value in surface_slots_by_id.values():
			var slot: SurfaceSlot = slot_value as SurfaceSlot
			if slot != null and slot.is_empty() and not slot.is_takeout_pickup_slot:
				target_slot = slot
				break
	if target_slot == null or not target_slot.is_empty():
		push_warning("Tutorial refill bowl slot unavailable; dropping bowl in world.")
		if bowls_node != null:
			bowl.detach_to_world(bowls_node, Vector2(480, 287.5))
		return false
	target_slot.store_bowl(bowl)
	target_slot.refresh_visual()
	return true


func _find_existing_empty_holder_for_order(order_id: int) -> OrderBowl:
	if order_id <= 0:
		return null
	if held_bowl != null and is_instance_valid(held_bowl) and held_bowl.order_id == order_id and held_bowl.is_empty_holder:
		return held_bowl
	_cache_surface_slots()
	for slot_value in surface_slots_by_id.values():
		var slot: SurfaceSlot = slot_value as SurfaceSlot
		if slot == null:
			continue
		var slot_bowl: OrderBowl = slot.get_stored_bowl()
		if slot_bowl != null and is_instance_valid(slot_bowl) and slot_bowl.order_id == order_id and slot_bowl.is_empty_holder:
			return slot_bowl
	for waiting_bowl in waiting_area.bowls:
		var waiting_order: OrderBowl = waiting_bowl as OrderBowl
		if waiting_order != null and is_instance_valid(waiting_order) and waiting_order.order_id == order_id and waiting_order.is_empty_holder:
			return waiting_order
	if bowls_node != null:
		for child in bowls_node.get_children():
			var world_bowl: OrderBowl = child as OrderBowl
			if world_bowl != null and is_instance_valid(world_bowl) and world_bowl.order_id == order_id and world_bowl.is_empty_holder:
				return world_bowl
	return null


func _refresh_surface_slot_containing_bowl(bowl: OrderBowl) -> void:
	if bowl == null:
		return
	_cache_surface_slots()
	for slot_value in surface_slots_by_id.values():
		var slot: SurfaceSlot = slot_value as SurfaceSlot
		if slot == null:
			continue
		if slot.get_stored_bowl() == bowl:
			slot.refresh_visual()
			return


func _refresh_dining_table_visual(table_id: int) -> void:
	if table_id < 1 or table_id > 2:
		return
	var table_node: Node = get_node_or_null("../Stations/DiningTables/DiningTable%d" % table_id)
	if table_node == null:
		return
	var label: Label = table_node.get_node_or_null("Label") as Label
	if label == null:
		return
	label.text = "桌%d 有垃圾" % table_id if bool(dirty_dining_tables.get(table_id, false)) else "桌%d" % table_id


func force_complete_one_order_for_smoke() -> bool:
	var guard: int = 0
	while _get_counter_customer() == null and guard < 900:
		await get_tree().process_frame
		guard += 1

	interact_counter()
	_process(0.7)
	if held_bowl == null:
		return false
	if not held_bowl.is_staple_ready_for_cooking():
		interact_staple_cabinet()
	interact_cooker(cooker_1)
	if cooker_1.active_bowl == null:
		return false
	if held_bowl == null:
		return false
	if not bool(held_bowl.is_empty_holder):
		return false

	cooker_1.active_bowl.update_cooking(8.2)
	if cooker_1.active_bowl.status != OrderBowl.STATUS_COOKED:
		return false
	interact_cooker(cooker_1)
	for action_name in ["sauce_x", "sauce_y", "sauce_a", "sauce_b"]:
		interact_with_station_action("SauceStationMixed", action_name)
	if held_bowl != null:
		for i in range(held_bowl.required_chili_count):
			interact_with_station_action("SauceStation", "sauce_x")

	if held_bowl == null:
		return false
	if held_bowl.service_mode == "takeout":
		interact_packing_area()
		_process(0.9)
		interact_packing_bag_area()
		_process(0.6)
		interact_surface_slot("TakeoutPickupSlot1")
	else:
		interact_delivery_table(held_bowl.table_id)

	return completed_orders > 0


func get_hand_text() -> String:
	if held_table_trash != 0:
		return "拿着桌%d的垃圾" % held_table_trash
	if held_pot != null:
		var pot_state: String = held_pot.get_content_status_text()
		if pot_state == "空锅":
			return "拿着空锅"
		return "拿着锅：%s" % pot_state
	if held_dirty_cooker != null:
		return "拿着脏锅 #%03d" % held_dirty_cooker.get_active_order_id()
	if held_bowl == null:
		return ""
	if held_bowl.needs_refill:
		return "拿着待补配订单 #%03d" % held_bowl.order_id
	if held_bowl.is_empty_holder:
		return "拿着空碗 #%03d" % held_bowl.order_id
	return "拿着订单 #%03d" % held_bowl.order_id


func _complete_held_order() -> void:
	if held_bowl != null and held_bowl.is_overcooked():
		_refresh_ui("订单 #%03d 已煮糊，请拿去垃圾桶" % held_bowl.order_id)
		return
	var bowl: OrderBowl = held_bowl
	if bowl != null and bowl.get_order_patience_ratio() <= 0.0:
		_fail_order_bowl(bowl, "订单 #%03d 等太久了，顾客离开" % bowl.order_id)
		return
	var tutorial_submission_block: String = _get_tutorial_submission_block_message(bowl)
	if tutorial_submission_block != "":
		_refresh_ui(tutorial_submission_block)
		return
	var completed_order_id: int = bowl.order_id
	var completed_service_mode: String = bowl.service_mode
	var completed_table_id: int = bowl.table_id
	tutorial_refill_holder_by_order_id.erase(completed_order_id)
	var result: Dictionary = _evaluate_order_quality(bowl)
	var earned_money: int = int(result.get("money", 0))
	var earned_score: int = int(result.get("score", 0)) + _evaluate_order_timing_score(bowl)
	var result_message: String = str(result.get("message", "出餐完成"))
	var customer: RestaurantCustomer = waiting_customers_by_order_id.get(bowl.order_id, null)
	if customer != null and is_instance_valid(customer):
		customer.complete_order(exit_point.global_position)
	waiting_customers_by_order_id.erase(bowl.order_id)
	_clear_all_order_objects(completed_order_id, bowl)
	bowl.mark_done()
	bowl.queue_free()
	held_bowl = null
	completed_orders += 1
	money_today += earned_money
	score_today += earned_score
	if completed_service_mode == "dine_in" and (completed_table_id == 1 or completed_table_id == 2):
		dirty_dining_tables[completed_table_id] = true
		_refresh_dining_table_visual(completed_table_id)
		_notify_tutorial("dining_table_became_dirty", {"table_id": completed_table_id})
	_update_score()
	_refresh_ui("完成订单 #%03d +%d：%s" % [completed_order_id, earned_money, result_message])
	_notify_tutorial("order_completed", {"order_id": completed_order_id, "service_mode": completed_service_mode})


func _evaluate_order_quality(bowl: OrderBowl) -> Dictionary:
	if bowl == null:
		return {"money": 0, "score": -3, "message": "空碗出单，顾客很不满意"}
	if bowl.is_empty_holder:
		return {"money": 0, "score": -3, "message": "空碗出单，顾客很不满意"}
	if bowl.is_overcooked():
		return {"money": 0, "score": -3, "message": "煮糊出单，顾客很不满意"}

	var money: int = 10
	var score: int = 0
	var problems: Array[String] = []

	if not bowl.has_food_content_for_serving():
		money -= 6
		score -= 2
		problems.append("没煮好")

	if not bowl.has_correct_staple():
		money -= 4
		score -= 2
		problems.append("主食不对")

	var missing_mixed: int = max(0, bowl.required_mixed_sauces.size() - bowl.get_mixed_sauce_count())
	if missing_mixed > 0:
		money -= missing_mixed
		score -= missing_mixed
		problems.append("缺小料%d种" % missing_mixed)

	var chili_diff: int = abs(bowl.required_chili_count - bowl.added_chili_count)
	if chili_diff > 0:
		money -= chili_diff
		score -= chili_diff
		problems.append("辣椒差%d次" % chili_diff)

	money = max(money, 0)
	var message: String = "出餐完成"
	if not problems.is_empty():
		message = "出餐完成，但质量有问题：" + "、".join(problems)
	return {"money": money, "score": score, "message": message}


func _evaluate_order_timing_score(bowl: OrderBowl) -> int:
	if bowl == null:
		return 0
	if bowl.get_order_patience_ratio() > 0.15:
		return 1
	return 0


func _hold_bowl(bowl: OrderBowl) -> void:
	if bowl == null:
		return
	held_bowl = bowl
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		bowl.attach_to_holder(player)


func _hold_pot(pot: CookingPot) -> void:
	if pot == null:
		return
	held_pot = pot
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		pot.attach_to_holder(player)


func _create_empty_holder_for_order(order_bowl: OrderBowl) -> OrderBowl:
	var holder: OrderBowl = OrderBowlScene.instantiate() as OrderBowl
	holder.setup_order(
		order_bowl.order_id,
		order_bowl.ingredients,
		order_bowl.staple_type,
		order_bowl.spice_level,
		order_bowl.service_mode,
		order_bowl.table_id,
		order_bowl.required_chili_count
	)
	holder.order_patience_max = order_bowl.order_patience_max
	holder.order_patience_current = order_bowl.order_patience_current
	holder.ingredient_time_required = order_bowl.ingredient_time_required
	holder.ready_window_seconds = order_bowl.ready_window_seconds
	holder.staple_added = order_bowl.staple_added
	holder.actual_staple_type = order_bowl.actual_staple_type
	holder.set_empty_holder_visual()
	bowls_node.add_child(holder)
	return holder


func _hold_dirty_cooker(cooker: CookerStation) -> void:
	if cooker == null or cooker.active_bowl == null or not cooker.active_bowl.is_overcooked():
		return
	held_dirty_cooker = cooker
	_attach_dirty_pot_visual(cooker.get_active_order_id())


func _clear_held_dirty_cooker() -> void:
	if held_dirty_cooker == null:
		_clear_dirty_pot_visual()
		return

	var cleared_bowl: OrderBowl = held_dirty_cooker.clear_overcooked_bowl()
	var cleared_order_id: int = 0
	if cleared_bowl != null:
		cleared_order_id = cleared_bowl.order_id
		var original_holder: OrderBowl = _find_original_holder_for_refill(cleared_order_id)
		if original_holder != null and is_instance_valid(original_holder):
			tutorial_refill_holder_by_order_id[cleared_order_id] = original_holder
			original_holder.mark_needs_refill()
			_refresh_surface_slot_containing_bowl(original_holder)
		else:
			push_warning("Overcooked order refill holder was not found; no new bowl will be created.")
		cleared_bowl.queue_free()

	held_dirty_cooker = null
	_clear_dirty_pot_visual()

	if cleared_order_id > 0:
		var refill_holder: OrderBowl = _find_original_holder_for_refill(cleared_order_id)
		if refill_holder != null and is_instance_valid(refill_holder) and refill_holder.needs_refill:
			_notify_tutorial("tutorial_overcook_cleared", {"bowl": refill_holder})
			_refresh_ui("食物倒掉了。先把空锅放回锅位，再拿起待补配订单盆。")
		else:
			_refresh_ui("食物已倒掉，但没有找到原订单盆，请找回订单盆继续补单。")
	else:
		_refresh_ui("脏锅已清理")


func _attach_dirty_pot_visual(order_id: int) -> void:
	_clear_dirty_pot_visual()
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	held_dirty_pot_visual = Node2D.new()
	held_dirty_pot_visual.name = "HeldDirtyPotVisual"
	player.add_child(held_dirty_pot_visual)
	held_dirty_pot_visual.position = Vector2(0, -42)
	held_dirty_pot_visual.z_index = 25

	var pot: Polygon2D = Polygon2D.new()
	pot.color = Color(0.12, 0.1, 0.08, 1.0)
	pot.polygon = PackedVector2Array([
		Vector2(-26, -12),
		Vector2(26, -12),
		Vector2(22, 16),
		Vector2(-22, 16)
	])
	held_dirty_pot_visual.add_child(pot)

	var label: Label = Label.new()
	label.name = "DirtyPotLabel"
	label.position = Vector2(-42, -34)
	label.size = Vector2(84, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = "脏锅 #%03d" % order_id
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	held_dirty_pot_visual.add_child(label)


func _clear_dirty_pot_visual() -> void:
	if held_dirty_pot_visual != null and is_instance_valid(held_dirty_pot_visual):
		held_dirty_pot_visual.queue_free()
	held_dirty_pot_visual = null


func _cache_surface_slots() -> void:
	surface_slots_by_id.clear()
	if surface_slots_parent == null:
		return
	for child in surface_slots_parent.get_children():
		var slot: SurfaceSlot = child as SurfaceSlot
		if slot == null:
			continue
		if slot.slot_id.strip_edges() == "":
			slot.slot_id = slot.name
		surface_slots_by_id[slot.slot_id] = slot
		slot.refresh_visual()


func _get_surface_slot(slot_id: String) -> SurfaceSlot:
	var slot: SurfaceSlot = surface_slots_by_id.get(slot_id, null) as SurfaceSlot
	if slot != null and is_instance_valid(slot):
		return slot
	_cache_surface_slots()
	return surface_slots_by_id.get(slot_id, null) as SurfaceSlot


func _clear_surface_slot_references(bowl: OrderBowl) -> void:
	if bowl == null:
		return
	for slot in surface_slots_by_id.values():
		var surface_slot: SurfaceSlot = slot as SurfaceSlot
		if surface_slot == null or not is_instance_valid(surface_slot):
			continue
		surface_slot.remove_bowl_if_matches(bowl)
		var pot: CookingPot = surface_slot.get_stored_pot()
		if pot != null and pot.content_bowl == bowl:
			pot.clear_content()
			surface_slot.refresh_visual()


func _clear_holder_bowls_for_order(order_id: int) -> void:
	if order_id <= 0:
		return
	if held_bowl != null and held_bowl.is_empty_holder and held_bowl.order_id == order_id:
		held_bowl.queue_free()
		held_bowl = null
	for slot in surface_slots_by_id.values():
		var surface_slot: SurfaceSlot = slot as SurfaceSlot
		if surface_slot == null or not is_instance_valid(surface_slot):
			continue
		var bowl: OrderBowl = surface_slot.get_stored_bowl()
		if bowl != null and bowl.is_empty_holder and bowl.order_id == order_id:
			surface_slot.remove_bowl_if_matches(bowl)
			bowl.queue_free()


func _clear_all_order_objects(order_id: int, except_bowl: OrderBowl = null) -> void:
	if order_id <= 0:
		return
	tutorial_refill_holder_by_order_id.erase(order_id)

	if held_bowl != null and is_instance_valid(held_bowl) and held_bowl.order_id == order_id and held_bowl != except_bowl:
		var clear_held_bowl: OrderBowl = held_bowl
		held_bowl = null
		clear_held_bowl.queue_free()

	if held_pot != null and is_instance_valid(held_pot):
		var held_content: OrderBowl = held_pot.content_bowl
		if held_content != null and is_instance_valid(held_content) and held_content.order_id == order_id and held_content != except_bowl:
			var cleared_held_content: OrderBowl = held_pot.clear_content()
			if cleared_held_content != null:
				cleared_held_content.queue_free()
			held_pot.refresh_visual()

	for waiting_bowl in waiting_area.bowls.duplicate():
		var waiting_order: OrderBowl = waiting_bowl as OrderBowl
		if waiting_order != null and is_instance_valid(waiting_order) and waiting_order.order_id == order_id and waiting_order != except_bowl:
			waiting_area.remove_bowl(waiting_order)
			waiting_order.queue_free()

	for cooker in [cooker_1, cooker_2]:
		if cooker == null or cooker.active_pot == null:
			continue
		var cooker_content: OrderBowl = cooker.active_pot.content_bowl
		if cooker_content != null and is_instance_valid(cooker_content) and cooker_content.order_id == order_id and cooker_content != except_bowl:
			var cleared_cooker_content: OrderBowl = cooker.clear_active_bowl()
			if cleared_cooker_content != null:
				cleared_cooker_content.queue_free()

	for slot in surface_slots_by_id.values():
		var surface_slot: SurfaceSlot = slot as SurfaceSlot
		if surface_slot == null or not is_instance_valid(surface_slot):
			continue
		var slot_bowl: OrderBowl = surface_slot.get_stored_bowl()
		if slot_bowl != null and is_instance_valid(slot_bowl) and slot_bowl.order_id == order_id and slot_bowl != except_bowl:
			surface_slot.remove_bowl_if_matches(slot_bowl)
			slot_bowl.queue_free()
			surface_slot.refresh_visual()
			continue
		var slot_pot: CookingPot = surface_slot.get_stored_pot()
		if slot_pot != null:
			var slot_content: OrderBowl = slot_pot.content_bowl
			if slot_content != null and is_instance_valid(slot_content) and slot_content.order_id == order_id and slot_content != except_bowl:
				var cleared_slot_content: OrderBowl = slot_pot.clear_content()
				if cleared_slot_content != null:
					cleared_slot_content.queue_free()
				slot_pot.refresh_visual()
				surface_slot.refresh_visual()


func _try_complete_takeout_from_surface(slot: SurfaceSlot, bowl: OrderBowl) -> bool:
	if slot == null or bowl == null or not is_instance_valid(bowl):
		return false
	if not slot.is_takeout_pickup_slot:
		return false
	if bowl.service_mode != "takeout" or bowl.status != OrderBowl.STATUS_PACKED:
		return false

	if bowl.get_order_patience_ratio() <= 0.0:
		_fail_order_bowl(bowl, "订单 #%03d 等太久了，顾客离开" % bowl.order_id)
		return true
	var tutorial_submission_block: String = _get_tutorial_submission_block_message(bowl)
	if tutorial_submission_block != "":
		_refresh_ui(tutorial_submission_block)
		return false

	var completed_order_id: int = bowl.order_id
	var completed_service_mode: String = bowl.service_mode
	var result: Dictionary = _evaluate_order_quality(bowl)
	var earned_money: int = int(result.get("money", 0))
	var earned_score: int = int(result.get("score", 0)) + _evaluate_order_timing_score(bowl)
	var result_message: String = str(result.get("message", "出餐完成"))
	var customer: RestaurantCustomer = waiting_customers_by_order_id.get(bowl.order_id, null)
	if customer != null and is_instance_valid(customer):
		customer.complete_order(exit_point.global_position)
	waiting_customers_by_order_id.erase(bowl.order_id)
	slot.remove_bowl_if_matches(bowl)
	_clear_all_order_objects(completed_order_id, bowl)
	bowl.mark_done()
	bowl.queue_free()
	completed_orders += 1
	money_today += earned_money
	score_today += earned_score
	_update_score()
	_refresh_ui("外带订单 #%03d 已完成 +%d：%s" % [completed_order_id, earned_money, result_message])
	_notify_tutorial("order_completed", {"order_id": completed_order_id, "service_mode": completed_service_mode})
	return true


func _get_counter_customer() -> RestaurantCustomer:
	for customer in queued_customers:
		if customer != null and is_instance_valid(customer) and customer.current_state == RestaurantCustomer.CustomerState.AT_COUNTER:
			return customer
	return null


func _estimate_weight(ingredients: Dictionary) -> int:
	var count: int = 0
	for item_id in ingredients.keys():
		count += int(ingredients[item_id])
	return 120 + count * 45


func _random_staple() -> String:
	var options: Array[String] = ["glass_noodle", "noodle", "none"]
	return options[randi() % options.size()]


func _random_spice() -> String:
	var options: Array[String] = ["mild", "medium", "hot"]
	return options[randi() % options.size()]


func _random_chili_count() -> int:
	var options: Array[int] = [0, 1, 2, 3]
	return options[randi() % options.size()]


func _spice_level_from_chili_count(chili_count: int) -> String:
	match chili_count:
		0:
			return "none"
		1:
			return "mild"
		2:
			return "medium"
		_:
			return "hot"


func _random_service_mode() -> String:
	var options: Array[String] = ["dine_in", "takeout"]
	return options[randi() % options.size()]


func _next_table_id() -> int:
	return ((next_order_id - 1) % 2) + 1


func _service_text(mode: String, table_id: int) -> String:
	if mode == "dine_in":
		return "堂食 桌%d" % table_id
	return "外带"


func _get_queue_spot(index: int) -> Vector2:
	var spots: Array[Node] = queue_spots_parent.get_children()
	if spots.is_empty():
		return counter_spot.global_position + Vector2(80 + index * 54, 0)
	var clamped_index: int = clamp(index, 0, spots.size() - 1)
	return (spots[clamped_index] as Node2D).global_position


func _get_table_spot(table_id: int) -> Vector2:
	var node: Node2D = table_spots_parent.get_node_or_null("TableSpot%d" % table_id) as Node2D
	if node != null:
		return node.global_position
	return Vector2(760, 330)


func _update_order_patience(delta: float) -> void:
	var bowls_to_fail: Array[OrderBowl] = []
	for bowl in _get_tracked_order_bowls():
		if bowl != null and is_instance_valid(bowl):
			bowl.update_order_patience(delta)
			if bowl.order_patience_current <= 0.0:
				bowls_to_fail.append(bowl)

	for failed_bowl in bowls_to_fail:
		if failed_bowl != null and is_instance_valid(failed_bowl):
			_fail_order_bowl(failed_bowl, "订单 #%03d 等太久了，顾客离开" % failed_bowl.order_id)


func _get_tracked_order_bowls() -> Array[OrderBowl]:
	var bowls: Array[OrderBowl] = []
	if held_bowl != null and is_instance_valid(held_bowl) and (not held_bowl.is_empty_holder or held_bowl.needs_refill):
		bowls.append(held_bowl)
	if held_pot != null and is_instance_valid(held_pot) and held_pot.content_bowl != null and is_instance_valid(held_pot.content_bowl):
		bowls.append(held_pot.content_bowl)
	for waiting_bowl in waiting_area.bowls:
		if waiting_bowl != null and is_instance_valid(waiting_bowl) and (not waiting_bowl.is_empty_holder or waiting_bowl.needs_refill) and waiting_bowl not in bowls:
			bowls.append(waiting_bowl)
	for cooker in [cooker_1, cooker_2]:
		if cooker != null and cooker.active_pot != null and cooker.active_pot.content_bowl != null and is_instance_valid(cooker.active_pot.content_bowl) and cooker.active_pot.content_bowl not in bowls:
			bowls.append(cooker.active_pot.content_bowl)
	for slot in surface_slots_by_id.values():
		var surface_slot: SurfaceSlot = slot as SurfaceSlot
		if surface_slot == null or not is_instance_valid(surface_slot):
			continue
		var slot_bowl: OrderBowl = surface_slot.get_stored_bowl()
		if slot_bowl != null and is_instance_valid(slot_bowl) and (not slot_bowl.is_empty_holder or slot_bowl.needs_refill) and slot_bowl not in bowls:
			bowls.append(slot_bowl)
		var slot_pot: CookingPot = surface_slot.get_stored_pot()
		if slot_pot != null and slot_pot.content_bowl != null and is_instance_valid(slot_pot.content_bowl) and slot_pot.content_bowl not in bowls:
			bowls.append(slot_pot.content_bowl)
	return bowls


func _has_active_content_for_order(order_id: int) -> bool:
	if order_id <= 0:
		return false

	if _bowl_is_active_content_for_order(held_bowl, order_id):
		return true
	if _pot_has_content_for_order(held_pot, order_id):
		return true

	for waiting_bowl in waiting_area.bowls:
		if _bowl_is_active_content_for_order(waiting_bowl, order_id):
			return true

	for cooker in [cooker_1, cooker_2]:
		if cooker != null and _pot_has_content_for_order(cooker.active_pot, order_id):
			return true

	for slot in surface_slots_by_id.values():
		var surface_slot: SurfaceSlot = slot as SurfaceSlot
		if surface_slot == null or not is_instance_valid(surface_slot):
			continue
		if _bowl_is_active_content_for_order(surface_slot.get_stored_bowl(), order_id):
			return true
		if _pot_has_content_for_order(surface_slot.get_stored_pot(), order_id):
			return true

	return false


func _bowl_is_active_content_for_order(bowl: OrderBowl, order_id: int) -> bool:
	return bowl != null and is_instance_valid(bowl) and not bowl.is_empty_holder and bowl.order_id == order_id


func _pot_has_content_for_order(pot: CookingPot, order_id: int) -> bool:
	if pot == null or not is_instance_valid(pot):
		return false
	var content: OrderBowl = pot.content_bowl
	return content != null and is_instance_valid(content) and content.order_id == order_id


func _handle_queue_patience_failures() -> void:
	var lost_customers: Array[RestaurantCustomer] = []
	for customer in queued_customers:
		if customer == null or not is_instance_valid(customer):
			continue
		if customer.queue_patience_current <= 0.0:
			lost_customers.append(customer)

	for customer in lost_customers:
		if customer == null or not is_instance_valid(customer):
			continue
		queued_customers.erase(customer)
		queue_lost_customers_today += 1
		score_today -= 1
		customer.complete_order(exit_point.global_position)
		_refresh_ui("排队顾客等太久离开了")

	if not lost_customers.is_empty():
		refresh_queue_positions()
		_update_score()


func _fail_order_bowl(bowl: OrderBowl, message: String) -> void:
	if bowl == null or not is_instance_valid(bowl):
		return

	var order_id: int = bowl.order_id
	if held_bowl == bowl:
		held_bowl = null
	if held_pot != null and held_pot.content_bowl == bowl:
		held_pot.clear_content()

	waiting_area.remove_bowl(bowl)
	_clear_surface_slot_references(bowl)

	for cooker in [cooker_1, cooker_2]:
		if cooker != null and cooker.active_pot != null and cooker.active_pot.content_bowl == bowl:
			cooker.clear_active_bowl()
			if held_dirty_cooker == cooker:
				held_dirty_cooker = null
				_clear_dirty_pot_visual()

	_clear_waiting_customer_for_order(order_id)
	_clear_holder_bowls_for_order(order_id)
	bowl.queue_free()
	_record_failed_order()
	_refresh_ui(message)


func _record_failed_order() -> void:
	failed_orders += 1
	score_today -= 3
	_update_score()


func _update_score() -> void:
	pass


func _check_day_end() -> void:
	if is_day_open or is_ending_day:
		return
	if _has_active_restaurant_work():
		return
	_finish_day_and_show_summary()


func _has_active_restaurant_work() -> bool:
	if held_dirty_cooker != null:
		return true
	if held_bowl != null and is_instance_valid(held_bowl) and (not held_bowl.is_empty_holder or held_bowl.needs_refill):
		return true
	if held_pot != null and is_instance_valid(held_pot) and held_pot.has_content():
		return true
	if not _get_tracked_order_bowls().is_empty():
		return true
	for customer_node in get_tree().get_nodes_in_group("restaurant_customers"):
		var customer: RestaurantCustomer = customer_node as RestaurantCustomer
		if customer != null and is_instance_valid(customer) and customer.current_state != RestaurantCustomer.CustomerState.LEAVING:
			return true
	return false


func _finish_day_and_show_summary() -> void:
	is_ending_day = true
	_update_score()
	var summary: Dictionary = {
		"day": current_day,
		"max_days": max_days,
		"completed_orders": completed_orders,
		"failed_orders": failed_orders,
		"queue_lost_customers": queue_lost_customers_today,
		"money_today": money_today,
		"score_today": score_today,
		"review_text": _get_review_text(score_today)
	}
	RestaurantRunState.record_day(summary)
	summary_transition_requested = true
	_refresh_ui("今日结束，进入结算")
	if auto_change_to_summary:
		call_deferred("_change_to_summary_scene")


func _change_to_summary_scene() -> void:
	get_tree().change_scene_to_file(NIGHT_SUMMARY_SCENE_PATH)


func _get_review_text(score: int) -> String:
	if score >= 30:
		return "今日评价：节奏不错"
	if score >= 10:
		return "今日评价：节奏还可以更稳"
	return "今日评价：明天重新找回节奏"


func _get_bowl_location_text(target_bowl: OrderBowl) -> String:
	if target_bowl == held_bowl:
		if target_bowl.status == OrderBowl.STATUS_WAITING:
			return "手中"
		return target_bowl.get_order_status_text()
	if held_pot != null and held_pot.content_bowl == target_bowl:
		return "手中锅"
	if waiting_area.bowls.has(target_bowl):
		return "待煮区"
	for cooker in [cooker_1, cooker_2]:
		if cooker != null and cooker.active_pot != null and cooker.active_pot.content_bowl == target_bowl:
			return "锅位1" if cooker == cooker_1 else "锅位2"
	for slot in surface_slots_by_id.values():
		var surface_slot: SurfaceSlot = slot as SurfaceSlot
		if surface_slot != null:
			if surface_slot.get_stored_bowl() == target_bowl:
				return surface_slot.slot_label
			var pot: CookingPot = surface_slot.get_stored_pot()
			if pot != null and pot.content_bowl == target_bowl:
				return surface_slot.slot_label
	return target_bowl.get_order_status_text()


func _refresh_ui(message: String = "") -> void:
	if ui == null:
		return

	if message == "" and _is_busy():
		message = _busy_status_text()
	ui.update_status(message)
	if _is_tutorial_time_paused() and ui.has_method("update_time_text"):
		ui.update_time_text("教学中")
	elif ui.has_method("update_time"):
		ui.update_time(day_time_remaining)

	var order_cards: Array[String] = []
	for bowl in _get_tracked_order_bowls():
		order_cards.append(_get_order_card_text(bowl))
	ui.update_order_cards(order_cards)


func _get_order_card_text(target_bowl: OrderBowl) -> String:
	var patience_percent: int = int(round(target_bowl.get_order_patience_ratio() * 100.0))
	return "#%03d\n%s\n主食：%s\n小料：%d/4\n辣椒：%d/%d\n目标：%s\n位置：%s\n耐心：%d%%" % [
		target_bowl.order_id,
		_service_text(target_bowl.service_mode, target_bowl.table_id),
		_staple_text(target_bowl.staple_type),
		target_bowl.get_mixed_sauce_count(),
		target_bowl.added_chili_count,
		target_bowl.required_chili_count,
		_delivery_destination_text(target_bowl),
		_get_bowl_location_text(target_bowl),
		patience_percent
	]


func _reject_overcooked_held_order() -> bool:
	if held_bowl == null or not held_bowl.is_overcooked():
		return false
	_refresh_ui("订单 #%03d 已煮糊，请拿去垃圾桶" % held_bowl.order_id)
	return true


func _clear_waiting_customer_for_order(order_id: int) -> void:
	var customer: RestaurantCustomer = waiting_customers_by_order_id.get(order_id, null)
	if customer != null and is_instance_valid(customer):
		customer.complete_order(exit_point.global_position)
	waiting_customers_by_order_id.erase(order_id)


func _staple_text(staple_type: String) -> String:
	match staple_type:
		"glass_noodle":
			return "粉丝"
		"noodle":
			return "面"
		"none":
			return "无主食"
		_:
			return staple_type


func _spice_text(spice_level: String) -> String:
	match spice_level:
		"none":
			return "不要辣"
		"mild":
			return "微辣"
		"medium":
			return "中辣"
		"hot":
			return "重辣"
		_:
			return spice_level


func _sauce_list_text(sauces: Array[String]) -> String:
	if sauces.is_empty():
		return "无"
	var parts: Array[String] = []
	for sauce in sauces:
		parts.append(_sauce_display_text(sauce))
	return "、".join(parts)


func _sauce_id_for_action(action_name: String) -> String:
	match action_name:
		"sauce_y":
			return "sesame_paste"
		"sauce_a":
			return "vinegar"
		"sauce_b":
			return "sugar"
		_:
			return "garlic_water"


func _sauce_display_text(sauce_id: String) -> String:
	match sauce_id:
		"garlic_water":
			return "蒜水"
		"sesame_paste":
			return "麻酱"
		"vinegar":
			return "醋"
		"sugar":
			return "糖"
		"chili":
			return "辣椒"
		"garlic":
			return "蒜"
		"cilantro":
			return "香菜"
		_:
			return sauce_id


func _delivery_destination_text(target_bowl: OrderBowl) -> String:
	if target_bowl.service_mode == "dine_in":
		return "桌%d" % target_bowl.table_id
	return "外带桌"
