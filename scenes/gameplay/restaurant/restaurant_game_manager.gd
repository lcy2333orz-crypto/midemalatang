class_name RestaurantGameManager
extends Node

const RestaurantCustomerScene = preload("res://scenes/gameplay/restaurant/restaurant_customer.tscn")
const ItemIds = preload("res://gameplay/models/item_ids.gd")

@export var max_customers: int = 5
@export var spawn_interval_seconds: float = 3.5

var queued_customers: Array[RestaurantCustomer] = []
var waiting_customers_by_order_id: Dictionary = {}
var completed_orders: int = 0
var next_order_id: int = 1
var spawn_count: int = 0
var spawn_elapsed: float = 0.0

var held_bowl: OrderBowl = null
var checkout_customer: RestaurantCustomer = null
var checkout_step: int = 0
var checkout_staple: String = "glass_noodle"
var checkout_spice: String = "mild"
var checkout_service_mode: String = "takeout"
var checkout_table_id: int = 1

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
	spawn_customer()
	_refresh_ui("Restaurant test loop started.")


func _process(delta: float) -> void:
	spawn_elapsed += delta
	if spawn_count < max_customers and spawn_elapsed >= spawn_interval_seconds:
		spawn_elapsed = 0.0
		spawn_customer()
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
	if checkout_customer == null or not is_instance_valid(checkout_customer):
		checkout_customer = _get_counter_customer()
		checkout_step = 0

	if checkout_customer == null:
		_refresh_ui("No customer at counter.")
		return

	match checkout_step:
		0:
			_refresh_ui("Weighed bowl: %dg. Choose staple next." % _estimate_weight(checkout_customer.get_bowl_ingredients()))
		1:
			checkout_staple = _next_staple(checkout_staple)
			_refresh_ui("Staple selected: %s." % checkout_staple)
		2:
			checkout_spice = _next_spice(checkout_spice)
			_refresh_ui("Spice selected: %s." % checkout_spice)
		3:
			checkout_service_mode = _next_service_mode(checkout_service_mode)
			checkout_table_id = _next_table_id() if checkout_service_mode == "dine_in" else 0
			_refresh_ui("Service selected: %s." % _service_text(checkout_service_mode, checkout_table_id))
		_:
			_create_order_from_checkout()
			return

	checkout_step += 1


func _create_order_from_checkout() -> void:
	var customer: RestaurantCustomer = checkout_customer
	if customer == null or customer.customer_bowl == null:
		_reset_checkout()
		return

	var bowl: OrderBowl = customer.customer_bowl
	var order_id: int = next_order_id
	next_order_id += 1

	bowl.setup_order(
		order_id,
		customer.get_bowl_ingredients(),
		checkout_staple,
		checkout_spice,
		checkout_service_mode,
		checkout_table_id
	)

	waiting_area.add_bowl(bowl)
	customer.customer_bowl = null

	queued_customers.erase(customer)
	waiting_customers_by_order_id[order_id] = customer
	var wait_position: Vector2 = takeout_wait.global_position
	if checkout_service_mode == "dine_in":
		wait_position = _get_table_spot(checkout_table_id)
	customer.wait_for_order(order_id, checkout_service_mode, checkout_table_id, wait_position)

	_refresh_ui("Order #%03d clipped and sent to waiting area." % order_id)
	_reset_checkout()
	refresh_queue_positions()


func interact_waiting_order_area() -> void:
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

	var bowl: OrderBowl = cooker.take_bowl()
	if bowl == null:
		_refresh_ui("Cooker is busy or empty.")
		return
	_hold_bowl(bowl)
	_refresh_ui("Took cooked bowl. Staple is %s." % bowl.staple_state)


func interact_sauce_station() -> void:
	if held_bowl == null:
		_refresh_ui("Hold a cooked bowl before adding sauces.")
		return
	if held_bowl.status != OrderBowl.STATUS_COOKED and held_bowl.status != OrderBowl.STATUS_SAUCED:
		_refresh_ui("Bowl must be cooked before sauce.")
		return
	held_bowl.add_next_sauce()
	_refresh_ui("Sauces: %s." % ",".join(held_bowl.sauces))


func interact_packing_area() -> void:
	if held_bowl == null:
		_refresh_ui("Hold a takeout bowl to pack.")
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
	if held_bowl == null:
		_refresh_ui("Hold a dine-in bowl to serve.")
		return
	if held_bowl.service_mode != "dine_in" or held_bowl.table_id != table_id:
		_refresh_ui("Wrong table.")
		return
	if not held_bowl.is_sauced():
		_refresh_ui("Add sauce before serving.")
		return
	_complete_held_order()


func interact_takeout_pickup() -> void:
	if held_bowl == null:
		_refresh_ui("Hold a packed takeout bowl.")
		return
	if held_bowl.service_mode != "takeout" or held_bowl.status != OrderBowl.STATUS_PACKED:
		_refresh_ui("Takeout orders must be packed first.")
		return
	_complete_held_order()


func interact_trash_bin() -> void:
	if held_bowl == null:
		_refresh_ui("Nothing to discard.")
		return
	held_bowl.queue_free()
	held_bowl = null
	_refresh_ui("Discarded held bowl.")


func force_complete_one_order_for_smoke() -> bool:
	var guard: int = 0
	while _get_counter_customer() == null and guard < 360:
		await get_tree().process_frame
		guard += 1

	for i in range(5):
		interact_counter()

	interact_waiting_order_area()
	interact_cooker(cooker_1)
	if cooker_1.bowl == null:
		return false

	cooker_1.bowl.update_cooking(4.2)
	interact_cooker(cooker_1)
	interact_sauce_station()

	if held_bowl == null:
		return false
	if held_bowl.service_mode == "takeout":
		interact_packing_area()
		interact_takeout_pickup()
	else:
		interact_delivery_table(held_bowl.table_id)

	return completed_orders > 0


func get_hand_text() -> String:
	if held_bowl == null:
		return "Hands: empty"
	return "Hands: %s" % held_bowl.get_summary_text()


func _complete_held_order() -> void:
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
	_refresh_ui("Completed order #%03d." % completed_order_id)


func _hold_bowl(bowl: OrderBowl) -> void:
	held_bowl = bowl
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		bowl.attach_to_holder(player)


func _get_counter_customer() -> RestaurantCustomer:
	for customer in queued_customers:
		if customer != null and is_instance_valid(customer) and customer.current_state == RestaurantCustomer.CustomerState.AT_COUNTER:
			return customer
	return null


func _reset_checkout() -> void:
	checkout_customer = null
	checkout_step = 0
	checkout_staple = "glass_noodle"
	checkout_spice = "mild"
	checkout_service_mode = "takeout" if next_order_id % 2 == 1 else "dine_in"


func _estimate_weight(ingredients: Dictionary) -> int:
	var count: int = 0
	for item_id in ingredients.keys():
		count += int(ingredients[item_id])
	return 120 + count * 45


func _next_staple(current: String) -> String:
	match current:
		"glass_noodle":
			return "noodle"
		"noodle":
			return "none"
		_:
			return "glass_noodle"


func _next_spice(current: String) -> String:
	match current:
		"mild":
			return "medium"
		"medium":
			return "hot"
		_:
			return "mild"


func _next_service_mode(current: String) -> String:
	return "takeout" if current == "dine_in" else "dine_in"


func _next_table_id() -> int:
	var next_table: int = ((next_order_id - 1) % 3) + 1
	return next_table


func _service_text(mode: String, table_id: int) -> String:
	if mode == "dine_in":
		return "table %d" % table_id
	return "takeout"


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

	var order_lines: Array[String] = []
	if held_bowl != null:
		order_lines.append("HELD %s" % held_bowl.get_detail_text())
	for bowl in waiting_area.bowls:
		order_lines.append("WAIT %s" % bowl.get_detail_text())
	for cooker in [cooker_1, cooker_2]:
		if cooker != null and cooker.bowl != null:
			order_lines.append("COOK %s %.1fs" % [cooker.bowl.get_detail_text(), cooker.bowl.cook_time])
	ui.update_orders("\n".join(order_lines))
