class_name RestaurantGameManager
extends Node

const RestaurantCustomerScene = preload("res://scenes/gameplay/restaurant/restaurant_customer.tscn")
const OrderBowlScene = preload("res://scenes/gameplay/restaurant/order_bowl.tscn")
const ItemIds = preload("res://gameplay/models/item_ids.gd")
const NIGHT_SUMMARY_SCENE_PATH = "res://scenes/restaurant_summary/restaurant_night_summary.tscn"

@export var max_customers: int = 3
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
@onready var surface_slots_parent: Node = $"../SurfaceSlots"
@onready var ui: RestaurantUI = $"../UI"

var surface_slots_by_id: Dictionary = {}


func _ready() -> void:
	add_to_group("restaurant_game_manager")
	randomize()
	_cache_surface_slots()
	_initialize_day_state()
	if is_day_open:
		spawn_customer()
	_refresh_ui("Restaurant day started.")


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


func _update_day_timer(delta: float) -> void:
	if not is_day_open:
		return
	day_time_remaining = max(day_time_remaining - delta, 0.0)
	if day_time_remaining <= 0.0:
		is_day_open = false
		spawn_elapsed = 0.0


func _process(delta: float) -> void:
	_update_day_timer(delta)
	if is_day_open:
		spawn_elapsed += delta
	if is_day_open and spawn_count < max_customers and spawn_elapsed >= spawn_interval_seconds:
		spawn_elapsed = 0.0
		spawn_customer()
	_update_order_patience(delta)
	_handle_queue_patience_failures()
	_update_score()
	_check_day_end()
	_refresh_ui()


func spawn_customer() -> RestaurantCustomer:
	if not is_day_open or spawn_count >= max_customers:
		return null

	var customer: RestaurantCustomer = RestaurantCustomerScene.instantiate() as RestaurantCustomer
	characters_node.add_child(customer)
	customer.setup(self, entrance.global_position, ingredient_display.global_position)
	spawn_count += 1
	return customer


func request_close_day() -> void:
	if is_ending_day:
		_refresh_ui("Entering summary.")
		if ui != null and ui.has_method("show_toast"):
			ui.show_toast("Entering summary.", 1.8)
		return
	is_day_open = false
	day_time_remaining = 0.0
	spawn_elapsed = 0.0
	_refresh_ui("Closed: no new customers. Finish remaining orders.")
	if ui != null and ui.has_method("show_toast"):
		ui.show_toast("Closed: no new customers.", 1.8)
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
		_refresh_ui("Clear dirty pot first.")
		return
	var customer: RestaurantCustomer = _get_counter_customer()
	if held_bowl != null:
		if customer != null:
			_refresh_ui("Put down what you are holding first.")
		else:
			interact_takeout_counter_delivery()
		return
	if customer == null:
		_refresh_ui("No customer at counter.")
		return

	_create_order_from_customer(customer)


func _create_order_from_customer(customer: RestaurantCustomer) -> void:
	if customer == null:
		return
	if held_bowl != null or held_dirty_cooker != null:
		_refresh_ui("Put down what you are holding first.")
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

	_hold_bowl(bowl)

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
		_refresh_ui("Clear dirty pot first.")
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


func interact_surface_slot(slot_id: String) -> void:
	if held_dirty_cooker != null:
		_refresh_ui("Clear dirty pot first.")
		return

	var slot: SurfaceSlot = _get_surface_slot(slot_id)
	if slot == null:
		_refresh_ui("Surface slot not found.")
		return

	if held_bowl != null:
		if not slot.is_empty():
			_refresh_ui("Table occupied.")
			return
		var placed_bowl: OrderBowl = held_bowl
		if not slot.store_bowl(placed_bowl):
			_refresh_ui("Could not place bowl.")
			return
		held_bowl = null
		if _try_complete_takeout_from_surface(slot, placed_bowl):
			return
		_refresh_ui("Placed order #%03d on %s." % [placed_bowl.order_id, slot.slot_label])
		return

	var bowl: OrderBowl = slot.take_bowl()
	if bowl == null:
		_refresh_ui("Table empty.")
		return
	_hold_bowl(bowl)
	_refresh_ui("Picked up order #%03d." % bowl.order_id)


func interact_cooker(cooker: CookerStation) -> void:
	if cooker == null:
		return

	if held_dirty_cooker != null:
		_refresh_ui("Clear dirty pot first.")
		return

	if held_bowl != null:
		if held_bowl.status != OrderBowl.STATUS_WAITING:
			_refresh_ui("Only waiting bowls can enter cooker.")
			return
		if not held_bowl.is_staple_ready_for_cooking():
			_refresh_ui("Add required staple first.")
			return
		if cooker.add_bowl(held_bowl):
			held_bowl = null
			_refresh_ui("Cooking started.")
		else:
			_refresh_ui("Cooker is occupied.")
		return

	if cooker.active_bowl != null and cooker.active_bowl.is_overcooked():
		_hold_dirty_cooker(cooker)
		_refresh_ui("Dirty pot #%03d. Take it to trash." % cooker.get_active_order_id())
		return

	var bowl: OrderBowl = cooker.take_bowl()
	if bowl == null:
		_refresh_ui("Cooker is busy or empty.")
		return
	_hold_bowl(bowl)
	_refresh_ui("Took cooked bowl. Staple is %s." % bowl.staple_state)


func interact_staple_cabinet() -> void:
	if held_dirty_cooker != null:
		_refresh_ui("Clear dirty pot first.")
		return
	if held_bowl == null:
		_refresh_ui("Hold an order bowl first.")
		return
	if held_bowl.status != OrderBowl.STATUS_WAITING:
		_refresh_ui("Only waiting orders need staple.")
		return
	if held_bowl.staple_type == "none":
		held_bowl.staple_added = true
		held_bowl.refresh_visuals()
		_refresh_ui("This order needs no staple.")
		return
	if held_bowl.staple_added:
		_refresh_ui("Staple already added.")
		return

	held_bowl.add_required_staple()
	_refresh_ui("Added staple: %s." % held_bowl.staple_type)


func interact_sauce_station() -> void:
	if held_dirty_cooker != null:
		_refresh_ui("Clear dirty pot first.")
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
		_refresh_ui("Clear dirty pot first.")
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
		_refresh_ui("Clear dirty pot first.")
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
		_refresh_ui("Clear dirty pot first.")
		return
	if held_bowl == null:
		_refresh_ui("Hold a packed takeout bowl.")
		return
	if _reject_overcooked_held_order():
		return
	if held_bowl.service_mode != "takeout" or held_bowl.status != OrderBowl.STATUS_PACKED:
		_refresh_ui("Pack takeout orders, then place them on TAKEOUT 1 or TAKEOUT 2.")
		return
	_refresh_ui("Use TAKEOUT 1 or TAKEOUT 2.")


func interact_takeout_counter_delivery() -> void:
	if held_bowl == null:
		return
	if _reject_overcooked_held_order():
		return
	if held_bowl.service_mode != "takeout":
		_refresh_ui("Dine-in order goes to assigned table.")
		return
	if held_bowl.status != OrderBowl.STATUS_PACKED:
		_refresh_ui("Pack takeout order first.")
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
	_clear_surface_slot_references(held_bowl)
	held_bowl.queue_free()
	held_bowl = null
	_record_failed_order()
	_refresh_ui("Discarded order #%03d" % discarded_order_id)


func force_complete_one_order_for_smoke() -> bool:
	var guard: int = 0
	while _get_counter_customer() == null and guard < 360:
		await get_tree().process_frame
		guard += 1

	interact_counter()
	if held_bowl == null:
		return false
	if not held_bowl.is_staple_ready_for_cooking():
		interact_staple_cabinet()
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
		interact_surface_slot("TakeoutPickupSlot1")
	else:
		interact_delivery_table(held_bowl.table_id)

	return completed_orders > 0


func get_hand_text() -> String:
	if held_dirty_cooker != null:
		return "Holding dirty pot #%03d" % held_dirty_cooker.get_active_order_id()
	if held_bowl == null:
		return ""
	return "Holding #%03d" % held_bowl.order_id


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
	_clear_surface_slot_references(bowl)
	bowl.mark_done()
	bowl.queue_free()
	held_bowl = null
	completed_orders += 1
	money_today += 10
	_update_score()
	_refresh_ui("Completed order #%03d +1" % completed_order_id)


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
		_clear_surface_slot_references(cleared_bowl)
		cleared_bowl.queue_free()
		_record_failed_order()

	held_dirty_cooker = null
	_clear_dirty_pot_visual()

	if cleared_order_id > 0:
		_refresh_ui("Order #%03d overcooked. Customer left." % cleared_order_id)
	else:
		_refresh_ui("Dirty pot cleared.")


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
	label.text = "Dirty pot #%03d" % order_id
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


func _try_complete_takeout_from_surface(slot: SurfaceSlot, bowl: OrderBowl) -> bool:
	if slot == null or bowl == null or not is_instance_valid(bowl):
		return false
	if not slot.is_takeout_pickup_slot:
		return false
	if bowl.service_mode != "takeout" or bowl.status != OrderBowl.STATUS_PACKED:
		return false

	var completed_order_id: int = bowl.order_id
	var customer: RestaurantCustomer = waiting_customers_by_order_id.get(bowl.order_id, null)
	if customer != null and is_instance_valid(customer):
		customer.complete_order(exit_point.global_position)
	waiting_customers_by_order_id.erase(bowl.order_id)
	slot.remove_bowl_if_matches(bowl)
	bowl.mark_done()
	bowl.queue_free()
	completed_orders += 1
	money_today += 10
	_update_score()
	_refresh_ui("Takeout order #%03d completed." % completed_order_id)
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


func _random_service_mode() -> String:
	var options: Array[String] = ["dine_in", "takeout"]
	return options[randi() % options.size()]


func _next_table_id() -> int:
	return ((next_order_id - 1) % 2) + 1


func _service_text(mode: String, table_id: int) -> String:
	if mode == "dine_in":
		return "DINE table %d" % table_id
	return "TAKEOUT"


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
			_fail_order_bowl(failed_bowl, "Order #%03d waited too long. Customer left." % failed_bowl.order_id)


func _get_tracked_order_bowls() -> Array[OrderBowl]:
	var bowls: Array[OrderBowl] = []
	if held_bowl != null and is_instance_valid(held_bowl):
		bowls.append(held_bowl)
	for waiting_bowl in waiting_area.bowls:
		if waiting_bowl != null and is_instance_valid(waiting_bowl) and waiting_bowl not in bowls:
			bowls.append(waiting_bowl)
	for cooker in [cooker_1, cooker_2]:
		if cooker != null and cooker.active_bowl != null and is_instance_valid(cooker.active_bowl) and cooker.active_bowl not in bowls:
			bowls.append(cooker.active_bowl)
	for slot in surface_slots_by_id.values():
		var surface_slot: SurfaceSlot = slot as SurfaceSlot
		if surface_slot == null or not is_instance_valid(surface_slot):
			continue
		var slot_bowl: OrderBowl = surface_slot.get_stored_bowl()
		if slot_bowl != null and is_instance_valid(slot_bowl) and slot_bowl not in bowls:
			bowls.append(slot_bowl)
	return bowls


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
		customer.complete_order(exit_point.global_position)
		_refresh_ui("Queue customer waited too long and left.")

	if not lost_customers.is_empty():
		refresh_queue_positions()
		_update_score()


func _fail_order_bowl(bowl: OrderBowl, message: String) -> void:
	if bowl == null or not is_instance_valid(bowl):
		return

	var order_id: int = bowl.order_id
	if held_bowl == bowl:
		held_bowl = null

	waiting_area.remove_bowl(bowl)
	_clear_surface_slot_references(bowl)

	for cooker in [cooker_1, cooker_2]:
		if cooker != null and cooker.active_bowl == bowl:
			cooker.clear_active_bowl()
			if held_dirty_cooker == cooker:
				held_dirty_cooker = null
				_clear_dirty_pot_visual()

	_clear_waiting_customer_for_order(order_id)
	bowl.queue_free()
	_record_failed_order()
	_refresh_ui(message)


func _record_failed_order() -> void:
	failed_orders += 1
	_update_score()


func _update_score() -> void:
	score_today = max(0, completed_orders * 10 - failed_orders * 8 - queue_lost_customers_today * 5)


func _check_day_end() -> void:
	if is_day_open or is_ending_day:
		return
	if _has_active_restaurant_work():
		return
	_finish_day_and_show_summary()


func _has_active_restaurant_work() -> bool:
	if held_bowl != null or held_dirty_cooker != null:
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
	_refresh_ui("Day ended. Entering summary.")
	if auto_change_to_summary:
		call_deferred("_change_to_summary_scene")


func _change_to_summary_scene() -> void:
	get_tree().change_scene_to_file(NIGHT_SUMMARY_SCENE_PATH)


func _get_review_text(score: int) -> String:
	if score >= 30:
		return "Review: smooth day."
	if score >= 10:
		return "Review: keep the pace steadier."
	return "Review: recover the rhythm tomorrow."


func _get_bowl_location_text(target_bowl: OrderBowl) -> String:
	if target_bowl == held_bowl:
		if target_bowl.status == OrderBowl.STATUS_WAITING:
			return "HELD"
		return target_bowl.get_order_status_text()
	if waiting_area.bowls.has(target_bowl):
		return "WAITING"
	for cooker in [cooker_1, cooker_2]:
		if cooker != null and cooker.active_bowl == target_bowl:
			return target_bowl.get_order_status_text()
	for slot in surface_slots_by_id.values():
		var surface_slot: SurfaceSlot = slot as SurfaceSlot
		if surface_slot != null and surface_slot.get_stored_bowl() == target_bowl:
			return surface_slot.slot_label
	return target_bowl.get_order_status_text()


func _refresh_ui(message: String = "") -> void:
	if ui == null:
		return

	ui.update_status(message)
	if ui.has_method("update_time"):
		ui.update_time(day_time_remaining)

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
			return "glass noodle"
		"noodle":
			return "noodle"
		"none":
			return "no staple"
		_:
			return staple_type


func _delivery_destination_text(target_bowl: OrderBowl) -> String:
	if target_bowl.service_mode == "dine_in":
		return "DINE %d" % target_bowl.table_id
	return "TAKEOUT 1/2"
