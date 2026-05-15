class_name RestaurantGameManager
extends Node

const RestaurantCustomerScene = preload("res://scenes/gameplay/restaurant/restaurant_customer.tscn")
const OrderBowlScene = preload("res://scenes/gameplay/restaurant/order_bowl.tscn")
const ItemIds = preload("res://gameplay/models/item_ids.gd")

@export var max_customers: int = 3
@export var spawn_interval_seconds: float = 6.0

var queued_customers: Array[RestaurantCustomer] = []
var waiting_customers_by_order_id: Dictionary = {}
var completed_orders: int = 0
var next_order_id: int = 1
var spawn_count: int = 0
var spawn_elapsed: float = 0.0

var held_bowl: OrderBowl = null
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
@onready var ui: RestaurantUI = $"../UI"


func _ready() -> void:
	add_to_group("restaurant_game_manager")
	randomize()
	spawn_customer()
	_refresh_ui("Restaurant test loop started.")


func _process(delta: float) -> void:
	spawn_elapsed += delta
	if spawn_count < max_customers and spawn_elapsed >= spawn_interval_seconds:
		spawn_elapsed = 0.0
		spawn_customer()
	_update_order_patience(delta)
	_refresh_ui()


func spawn_customer() -> RestaurantCustomer:
	if spawn_count >= max_customers:
		return null

	var customer: RestaurantCustomer = RestaurantCustomerScene.instantiate() as RestaurantCustomer
	characters_node.add_child(customer)
	customer.setup(self, entrance.global_position, ingredient_display.global_position)
	spawn_count += 1
	return customer


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
	match station_name:
		"Counter":
			interact_counter()
		"WaitingOrderArea":
			interact_waiting_order_area()
		"CookerStation1":
			interact_cooker(cooker_1)
		"CookerStation2":
			interact_cooker(cooker_2)
		"SauceStation":
			interact_sauce_station()
		"PackingArea":
			interact_packing_area()
		"DiningTable1":
			interact_delivery_table(1)
		"DiningTable2":
			interact_delivery_table(2)
		"DiningTable3":
			interact_delivery_table(3)
		"TakeoutPickup":
			interact_takeout_pickup()
		"TrashBin":
			interact_trash_bin()
		_:
			_refresh_ui("No restaurant action for %s." % station_name)


func interact_counter() -> void:
	if held_dirty_cooker != null:
		_refresh_ui("先把脏锅倒进垃圾桶。")
		return
	if held_bowl != null:
		interact_takeout_counter_delivery()
		return
	var customer: RestaurantCustomer = _get_counter_customer()
	if customer == null:
		_refresh_ui("No customer at counter.")
		return

	_create_order_from_customer(customer)


func _create_order_from_customer(customer: RestaurantCustomer) -> void:
	if customer == null:
		return

	var ingredients: Dictionary = customer.get_bowl_ingredients()
	if ingredients.is_empty():
		_refresh_ui("Customer has not picked ingredients.")
		return

	var bowl: OrderBowl = OrderBowlScene.instantiate() as OrderBowl
	var order_id: int = next_order_id
	next_order_id += 1
	var staple_type: String = _random_staple()
	var spice_level: String = _random_spice()
	var service_mode: String = _random_service_mode()
	var table_id: int = _next_table_id() if service_mode == "dine_in" else 0

	bowl.setup_order(
		order_id,
		ingredients,
		staple_type,
		spice_level,
		service_mode,
		table_id
	)

	if not waiting_area.add_bowl(bowl):
		bowl.queue_free()
		_refresh_ui("Waiting area is full.")
		return

	queued_customers.erase(customer)
	waiting_customers_by_order_id[order_id] = customer
	var wait_position: Vector2 = takeout_wait.global_position
	if service_mode == "dine_in":
		wait_position = _get_table_spot(table_id)
	customer.wait_for_order(order_id, service_mode, table_id, wait_position)

	_refresh_ui("Order #%03d created: %s / %s / %s." % [
		order_id,
		staple_type,
		spice_level,
		_service_text(service_mode, table_id)
	])
	refresh_queue_positions()


func interact_waiting_order_area() -> void:
	if held_dirty_cooker != null:
		_refresh_ui("先把脏锅倒进垃圾桶。")
		return

	if held_bowl == null:
		var bowl: OrderBowl = waiting_area.take_first_bowl()
		if bowl == null:
			_refresh_ui("Waiting area is empty.")
			return
		_hold_bowl(bowl)
		_refresh_ui("Picked up %s." % bowl.get_summary_text())
		return

	if held_bowl.status == OrderBowl.STATUS_WAITING:
		if waiting_area.add_bowl(held_bowl):
			held_bowl = null
			_refresh_ui("Returned bowl to waiting area.")
		else:
			_refresh_ui("Waiting area is full.")
	else:
		_refresh_ui("This bowl should go forward, not back to waiting.")


func interact_cooker(cooker: CookerStation) -> void:
	if cooker == null:
		return

	if held_dirty_cooker != null:
		_refresh_ui("先把脏锅倒进垃圾桶。")
		return

	if held_bowl != null:
		if held_bowl.status != OrderBowl.STATUS_WAITING:
			_refresh_ui("Only waiting bowls can enter cooker.")
			return
		if cooker.add_bowl(held_bowl):
			held_bowl = null
			_refresh_ui("Cooking started.")
		else:
			_refresh_ui("Cooker is occupied.")
		return

	if cooker.active_bowl != null and cooker.active_bowl.is_overcooked():
		_hold_dirty_cooker(cooker)
		_refresh_ui("拿起脏锅 #%03d，去垃圾桶清理。" % cooker.get_active_order_id())
		return

	var bowl: OrderBowl = cooker.take_bowl()
	if bowl == null:
		_refresh_ui("Cooker is busy or empty.")
		return
	_hold_bowl(bowl)
	_refresh_ui("Took cooked bowl. Staple is %s." % bowl.staple_state)


func interact_sauce_station() -> void:
	if held_dirty_cooker != null:
		_refresh_ui("先把脏锅倒进垃圾桶。")
		return
	if held_bowl == null:
		_refresh_ui("Hold a cooked bowl before adding sauces.")
		return
	if _reject_overcooked_held_order():
		return
	if held_bowl.status != OrderBowl.STATUS_COOKED and held_bowl.status != OrderBowl.STATUS_SAUCED:
		_refresh_ui("Bowl must be cooked before sauce.")
		return
	held_bowl.add_next_sauce()
	_refresh_ui("Sauces: %s." % ",".join(held_bowl.sauces))


func interact_packing_area() -> void:
	if held_dirty_cooker != null:
		_refresh_ui("先把脏锅倒进垃圾桶。")
		return
	if held_bowl == null:
		_refresh_ui("Hold a takeout bowl to pack.")
		return
	if _reject_overcooked_held_order():
		return
	if held_bowl.service_mode != "takeout":
		_refresh_ui("Dine-in orders go to tables.")
		return
	if not held_bowl.is_sauced():
		_refresh_ui("Add sauce before packing.")
		return
	held_bowl.mark_packed()
	_refresh_ui("Packed order #%03d." % held_bowl.order_id)


func interact_delivery_table(table_id: int) -> void:
	if held_dirty_cooker != null:
		_refresh_ui("先把脏锅倒进垃圾桶。")
		return
	if held_bowl == null:
		_refresh_ui("Hold a dine-in bowl to serve.")
		return
	if _reject_overcooked_held_order():
		return
	if held_bowl.service_mode != "dine_in" or held_bowl.table_id != table_id:
		_refresh_ui("Wrong table.")
		return
	if not held_bowl.is_sauced():
		_refresh_ui("Add sauce before serving.")
		return
	_complete_held_order()


func interact_takeout_pickup() -> void:
	if held_dirty_cooker != null:
		_refresh_ui("先把脏锅倒进垃圾桶。")
		return
	if held_bowl == null:
		_refresh_ui("Hold a packed takeout bowl.")
		return
	if _reject_overcooked_held_order():
		return
	if held_bowl.service_mode != "takeout" or held_bowl.status != OrderBowl.STATUS_PACKED:
		_refresh_ui("外带订单打包后交给收银台。")
		return
	_refresh_ui("外带订单交给收银台。")


func interact_takeout_counter_delivery() -> void:
	if held_bowl == null:
		return
	if _reject_overcooked_held_order():
		return
	if held_bowl.service_mode != "takeout":
		_refresh_ui("堂食订单送到对应堂食桌。")
		return
	if held_bowl.status != OrderBowl.STATUS_PACKED:
		_refresh_ui("外带订单需要先去打包台。")
		return
	_complete_held_order()


func interact_trash_bin() -> void:
	if held_dirty_cooker != null:
		_clear_held_dirty_cooker()
		return

	if held_bowl == null:
		_refresh_ui("Nothing to discard.")
		return
	var discarded_order_id: int = held_bowl.order_id
	_clear_waiting_customer_for_order(discarded_order_id)
	held_bowl.queue_free()
	held_bowl = null
	_refresh_ui("丢弃订单 #%03d" % discarded_order_id)


func force_complete_one_order_for_smoke() -> bool:
	var guard: int = 0
	while _get_counter_customer() == null and guard < 360:
		await get_tree().process_frame
		guard += 1

	interact_counter()

	interact_waiting_order_area()
	interact_cooker(cooker_1)
	if cooker_1.active_bowl == null:
		return false
	if cooker_1.holder_bowl == null:
		return false
	if not bool(cooker_1.holder_bowl.is_empty_holder):
		return false

	cooker_1.active_bowl.update_cooking(8.2)
	if cooker_1.active_bowl.status != OrderBowl.STATUS_COOKED:
		return false
	interact_cooker(cooker_1)
	interact_sauce_station()

	if held_bowl == null:
		return false
	if held_bowl.service_mode == "takeout":
		interact_packing_area()
		interact_counter()
	else:
		interact_delivery_table(held_bowl.table_id)

	return completed_orders > 0


func get_hand_text() -> String:
	if held_dirty_cooker != null:
		return "拿着脏锅 #%03d" % held_dirty_cooker.get_active_order_id()
	if held_bowl == null:
		return ""
	return "拿着 #%03d" % held_bowl.order_id


func _complete_held_order() -> void:
	if held_bowl != null and held_bowl.is_overcooked():
		_refresh_ui("Order #%03d is overcooked. Use the trash bin." % held_bowl.order_id)
		return
	var bowl: OrderBowl = held_bowl
	var completed_order_id: int = bowl.order_id
	var customer: RestaurantCustomer = waiting_customers_by_order_id.get(bowl.order_id, null)
	if customer != null and is_instance_valid(customer):
		customer.complete_order(exit_point.global_position)
	waiting_customers_by_order_id.erase(bowl.order_id)
	bowl.mark_done()
	bowl.queue_free()
	held_bowl = null
	completed_orders += 1
	_refresh_ui("完成订单 #%03d +1" % completed_order_id)


func _hold_bowl(bowl: OrderBowl) -> void:
	held_bowl = bowl
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		bowl.attach_to_holder(player)


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
		_clear_waiting_customer_for_order(cleared_order_id)
		cleared_bowl.queue_free()

	held_dirty_cooker = null
	_clear_dirty_pot_visual()

	if cleared_order_id > 0:
		_refresh_ui("订单 #%03d 煮烂，顾客生气离开" % cleared_order_id)
	else:
		_refresh_ui("脏锅已经清空。")


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


func _random_service_mode() -> String:
	var options: Array[String] = ["dine_in", "takeout"]
	return options[randi() % options.size()]


func _next_table_id() -> int:
	var next_table: int = ((next_order_id - 1) % 3) + 1
	return next_table


func _service_text(mode: String, table_id: int) -> String:
	if mode == "dine_in":
		return "堂食 桌%d" % table_id
	return "打包"


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
	for bowl in _get_tracked_order_bowls():
		if bowl != null and is_instance_valid(bowl):
			bowl.update_order_patience(delta)


func _get_tracked_order_bowls() -> Array[OrderBowl]:
	var bowls: Array[OrderBowl] = []
	if held_bowl != null:
		bowls.append(held_bowl)
	for waiting_bowl in waiting_area.bowls:
		if waiting_bowl != null and waiting_bowl not in bowls:
			bowls.append(waiting_bowl)
	for cooker in [cooker_1, cooker_2]:
		if cooker != null and cooker.active_bowl != null and cooker.active_bowl not in bowls:
			bowls.append(cooker.active_bowl)
	return bowls


func _get_bowl_location_text(target_bowl: OrderBowl) -> String:
	if target_bowl == held_bowl:
		if target_bowl.status == OrderBowl.STATUS_WAITING:
			return "手持"
		return target_bowl.get_order_status_text()
	if waiting_area.bowls.has(target_bowl):
		return "等待中"
	for cooker in [cooker_1, cooker_2]:
		if cooker != null and cooker.active_bowl == target_bowl:
			return target_bowl.get_order_status_text()
	return target_bowl.get_order_status_text()


func _refresh_ui(message: String = "") -> void:
	if ui == null:
		return

	var line: String = "Completed: %d | Queue: %d | Spawned: %d/%d" % [
		completed_orders,
		queued_customers.size(),
		spawn_count,
		max_customers
	]
	if message != "":
		line += "\n%s" % message
	ui.update_status(line)

	var order_cards: Array[String] = []
	for bowl in _get_tracked_order_bowls():
		order_cards.append(_get_order_card_text(bowl))
	ui.update_order_cards(order_cards)


func _get_order_card_text(target_bowl: OrderBowl) -> String:
	var patience_percent: int = int(round(target_bowl.get_order_patience_ratio() * 100.0))
	return "#%03d\n%s\n%s\n%s\n%s\n%d%%" % [
		target_bowl.order_id,
		_service_text(target_bowl.service_mode, target_bowl.table_id),
		_staple_text(target_bowl.staple_type),
		_delivery_destination_text(target_bowl),
		_get_bowl_location_text(target_bowl),
		patience_percent
	]


func _reject_overcooked_held_order() -> bool:
	if held_bowl == null or not held_bowl.is_overcooked():
		return false
	_refresh_ui("Order #%03d is overcooked. Use the trash bin." % held_bowl.order_id)
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


func _delivery_destination_text(target_bowl: OrderBowl) -> String:
	if target_bowl.service_mode == "dine_in":
		return "堂食桌%d" % target_bowl.table_id
	return "收银台"
