class_name RestaurantCustomer
extends CharacterBody2D

const ItemIds = preload("res://gameplay/models/item_ids.gd")

enum CustomerState {
	ENTERING,
	CHOOSING,
	QUEUEING,
	AT_COUNTER,
	WAITING_TABLE,
	WAITING_TAKEOUT,
	LEAVING
}

@export var move_speed: float = 80.0

var manager: Node = null
var current_state: CustomerState = CustomerState.ENTERING
var target_position: Vector2 = Vector2.ZERO
var desired_queue_index: int = -1
var selected_ingredients: Dictionary = {}
var order_id: int = 0
var service_mode: String = "dine_in"
var table_id: int = 0
var queue_patience_max: float = 100.0
var queue_patience_current: float = 100.0

var status_label: Label
var patience_bar: ProgressBar


func _ready() -> void:
	add_to_group("restaurant_customers")
	_ensure_visuals()
	_set_status("in")


func _physics_process(_delta: float) -> void:
	_update_queue_patience(_delta)

	var to_target: Vector2 = target_position - global_position
	if to_target.length() > 5.0:
		velocity = to_target.normalized() * move_speed
		move_and_slide()
		return

	velocity = Vector2.ZERO
	move_and_slide()
	_on_reached_target()


func setup(new_manager: Node, entrance_position: Vector2, display_position: Vector2) -> void:
	manager = new_manager
	global_position = entrance_position
	target_position = display_position
	current_state = CustomerState.ENTERING
	_set_status("pick")


func move_to_queue(queue_position: Vector2, queue_index: int) -> void:
	desired_queue_index = queue_index
	target_position = queue_position
	current_state = CustomerState.QUEUEING
	_set_status("queue")


func move_to_counter(counter_position: Vector2) -> void:
	desired_queue_index = 0
	target_position = counter_position
	current_state = CustomerState.QUEUEING
	_set_status("pay")


func mark_at_counter() -> void:
	current_state = CustomerState.AT_COUNTER
	_set_status("cashier")


func wait_for_order(new_order_id: int, new_service_mode: String, new_table_id: int, wait_position: Vector2) -> void:
	order_id = new_order_id
	service_mode = new_service_mode
	table_id = new_table_id
	target_position = wait_position
	current_state = CustomerState.WAITING_TABLE if service_mode == "dine_in" else CustomerState.WAITING_TAKEOUT
	_set_status("table %d" % table_id if service_mode == "dine_in" else "takeout")
	_update_patience_bar_visibility()


func complete_order(exit_position: Vector2) -> void:
	target_position = exit_position
	current_state = CustomerState.LEAVING
	_set_status("done")


func get_bowl_ingredients() -> Dictionary:
	return selected_ingredients.duplicate(true)


func _on_reached_target() -> void:
	if current_state == CustomerState.ENTERING:
		_select_ingredients()
		current_state = CustomerState.CHOOSING
		_set_status("picked")
		if manager != null and manager.has_method("enqueue_customer"):
			manager.enqueue_customer(self)
		return

	if current_state == CustomerState.QUEUEING:
		if desired_queue_index == 0:
			mark_at_counter()
		return

	if current_state == CustomerState.LEAVING:
		queue_free()


func _select_ingredients() -> void:
	if not selected_ingredients.is_empty():
		return

	var ingredient_pool: Array[String] = ItemIds.BASIC_INGREDIENTS.duplicate()
	ingredient_pool.shuffle()

	var ingredient_count: int = randi_range(1, min(3, ingredient_pool.size()))
	for i in range(ingredient_count):
		selected_ingredients[ingredient_pool[i]] = randi_range(1, 2)


func _ensure_visuals() -> void:
	if get_node_or_null("Visual") == null:
		var visual: Node2D = Node2D.new()
		visual.name = "Visual"
		add_child(visual)
		var body: Polygon2D = Polygon2D.new()
		body.color = Color(0.35, 0.95, 0.45, 1.0)
		body.polygon = PackedVector2Array([
			Vector2(-9, -12),
			Vector2(9, -12),
			Vector2(9, 12),
			Vector2(-9, 12)
		])
		visual.add_child(body)

	if status_label == null:
		status_label = Label.new()
		status_label.name = "RestaurantCustomerStatus"
		status_label.position = Vector2(-32, -44)
		status_label.size = Vector2(64, 18)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status_label.add_theme_font_size_override("font_size", 10)
		status_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.65, 1.0))
		status_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 1.0))
		status_label.add_theme_constant_override("outline_size", 3)
		add_child(status_label)

	if patience_bar == null:
		patience_bar = ProgressBar.new()
		patience_bar.name = "QueuePatienceBar"
		patience_bar.position = Vector2(-18, -28)
		patience_bar.size = Vector2(36, 6)
		patience_bar.min_value = 0.0
		patience_bar.max_value = queue_patience_max
		patience_bar.value = queue_patience_current
		patience_bar.show_percentage = false
		add_child(patience_bar)
		_update_patience_bar_visibility()


func _set_status(text: String) -> void:
	_ensure_visuals()
	status_label.text = text


func _update_queue_patience(delta: float) -> void:
	if current_state == CustomerState.QUEUEING or current_state == CustomerState.AT_COUNTER:
		queue_patience_current = max(queue_patience_current - delta * 2.0, 0.0)
	if patience_bar != null:
		patience_bar.value = queue_patience_current
	_update_patience_bar_visibility()


func _update_patience_bar_visibility() -> void:
	if patience_bar == null:
		return
	patience_bar.visible = current_state == CustomerState.QUEUEING or current_state == CustomerState.AT_COUNTER
