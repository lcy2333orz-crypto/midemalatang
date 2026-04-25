extends CharacterBody2D

enum CustomerState {
	MOVING_TO_QUEUE,
	WAITING_IN_QUEUE,
	AT_COUNTER,
	ORDER_NEGOTIATING,
	MOVING_TO_DELIVERY,
	WAITING_AT_DELIVERY,
	MOVING_TO_EXIT
}

const ITEM_NONE := "none"
const ITEM_GLASS_NOODLE := "glass_noodle"
const ITEM_NOODLE := "noodle"
const ITEM_SPINACH := "spinach"
const ITEM_POTATO_SLICE := "potato_slice"
const ITEM_TOFU_PUFF := "tofu_puff"

@export var move_speed: float = 120.0
@export var target_position: Vector2 = Vector2.ZERO

var current_state: CustomerState = CustomerState.MOVING_TO_QUEUE
var order_name_key: String = "UI_ORDER_NAME_MALATANG"
var main_food_id: String = ITEM_NONE
var needs_waiting: bool = false
var ingredients: Dictionary = {}

# ===== 特殊顾客接口（当前先只留通用字段） =====
var is_special_customer: bool = false
var special_customer_type: String = ""
var special_customer_name: String = ""
var special_result_recorded: bool = false

var is_waiting_for_food: bool = false
var is_ready_for_delivery: bool = false
var is_waiting_after_checkout: bool = false
var order_served: bool = false

var needs_main_food_cooking: bool = false
var needs_ingredient_cooking: bool = false
var needs_emergency_purchase: bool = false

var is_checked_out: bool = false
var order_revealed: bool = false

var paid_price: int = 0
var true_price_at_checkout: int = 0
var price_reaction_result: String = "accept"

var counter_patience_max: float = 100.0
var counter_patience_current: float = 100.0
var delivery_patience_max: float = 100.0
var delivery_patience_current: float = 100.0

var patience_drain_counter: float = 4.0
var patience_drain_delivery: float = 2.0

var queue_index: int = -1
var is_in_queue: bool = true
var leaving_due_to_patience: bool = false

var patience_bar_bg: ColorRect
var patience_bar_fill: ColorRect

func _ready() -> void:
	add_to_group("customers")
	randomize_order()
	reset_patience()
	_create_patience_bar()

func _physics_process(delta: float) -> void:
	_update_patience(delta)
	_update_patience_bar()

	if current_state == CustomerState.WAITING_IN_QUEUE \
	or current_state == CustomerState.AT_COUNTER \
	or current_state == CustomerState.ORDER_NEGOTIATING \
	or current_state == CustomerState.WAITING_AT_DELIVERY:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_target := target_position - global_position

	if to_target.length() > 5.0:
		var direction := to_target.normalized()
		velocity = direction * move_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		move_and_slide()
		_on_reached_target()

func _create_patience_bar() -> void:
	patience_bar_bg = ColorRect.new()
	patience_bar_bg.color = Color(0.15, 0.15, 0.15, 0.9)
	patience_bar_bg.size = Vector2(36, 5)
	patience_bar_bg.position = Vector2(-18, -30)
	patience_bar_bg.visible = false
	add_child(patience_bar_bg)

	patience_bar_fill = ColorRect.new()
	patience_bar_fill.color = Color(0.3, 0.9, 0.3, 0.95)
	patience_bar_fill.size = Vector2(36, 5)
	patience_bar_fill.position = Vector2.ZERO
	patience_bar_bg.add_child(patience_bar_fill)

func _update_patience_bar() -> void:
	if patience_bar_bg == null or patience_bar_fill == null:
		return

	var show_bar := is_in_queue and not is_checked_out
	patience_bar_bg.visible = show_bar

	if not show_bar:
		return

	var ratio := 0.0
	if counter_patience_max > 0.0:
		ratio = clamp(counter_patience_current / counter_patience_max, 0.0, 1.0)

	patience_bar_fill.size.x = 36.0 * ratio

	if ratio > 0.6:
		patience_bar_fill.color = Color(0.3, 0.9, 0.3, 0.95)
	elif ratio > 0.3:
		patience_bar_fill.color = Color(0.95, 0.75, 0.2, 0.95)
	else:
		patience_bar_fill.color = Color(0.95, 0.3, 0.3, 0.95)

func _update_patience(delta: float) -> void:
	if order_served:
		return

	if is_waiting_after_checkout:
		delivery_patience_current -= patience_drain_delivery * delta
		if delivery_patience_current <= 0.0:
			delivery_patience_current = 0.0
			_leave_due_to_no_patience()
	elif current_state == CustomerState.WAITING_IN_QUEUE \
	or current_state == CustomerState.AT_COUNTER \
	or current_state == CustomerState.ORDER_NEGOTIATING:
		counter_patience_current -= patience_drain_counter * delta
		if counter_patience_current <= 0.0:
			counter_patience_current = 0.0
			_leave_due_to_no_patience()

func _leave_due_to_no_patience() -> void:
	if current_state == CustomerState.MOVING_TO_EXIT:
		return

	var game_ui = get_tree().get_first_node_in_group("game_ui")
	if game_ui:
		game_ui.hide_order()
		game_ui.hide_patience()

	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		if game_manager.has_method("handle_customer_patience_timeout"):
			game_manager.handle_customer_patience_timeout(self)
		game_manager.notify_customer_leaving(self)

	print("Customer lost patience and left.")

	current_state = CustomerState.MOVING_TO_EXIT
	is_waiting_after_checkout = false
	order_served = false
	is_in_queue = false
	queue_index = -1
	leaving_due_to_patience = true

	var exit_point = get_tree().get_first_node_in_group("exit_point")
	if exit_point:
		target_position = exit_point.global_position
	else:
		queue_free()

func _on_reached_target() -> void:
	match current_state:
		CustomerState.MOVING_TO_QUEUE:
			if queue_index == 0:
				current_state = CustomerState.AT_COUNTER
			else:
				current_state = CustomerState.WAITING_IN_QUEUE

		CustomerState.MOVING_TO_DELIVERY:
			current_state = CustomerState.WAITING_AT_DELIVERY
			print("Customer reached delivery point and is now waiting.")

		CustomerState.MOVING_TO_EXIT:
			queue_free()

func move_to_queue_position(queue_position: Vector2, new_queue_index: int) -> void:
	if not is_in_queue:
		return

	queue_index = new_queue_index

	if global_position.distance_to(queue_position) <= 5.0:
		target_position = queue_position
		if queue_index == 0:
			current_state = CustomerState.AT_COUNTER
		else:
			current_state = CustomerState.WAITING_IN_QUEUE
		return

	target_position = queue_position
	current_state = CustomerState.MOVING_TO_QUEUE

func go_to_delivery(delivery_position: Vector2) -> void:
	is_in_queue = false
	queue_index = -1
	target_position = delivery_position
	current_state = CustomerState.MOVING_TO_DELIVERY
	leaving_due_to_patience = false
	print("Customer is moving to delivery point: ", delivery_position)

func go_to_exit(exit_position: Vector2) -> void:
	is_in_queue = false
	queue_index = -1
	target_position = exit_position
	current_state = CustomerState.MOVING_TO_EXIT
	is_waiting_after_checkout = false
	leaving_due_to_patience = false
	print("Customer is moving to exit: ", exit_position)

func randomize_order() -> void:
	randomize_main_food()
	randomize_ingredients()
	needs_waiting = has_main_food()

func randomize_main_food() -> void:
	var roll := randi() % 3

	match roll:
		0:
			main_food_id = ITEM_NONE
		1:
			main_food_id = ITEM_GLASS_NOODLE
		2:
			main_food_id = ITEM_NOODLE

func randomize_ingredients() -> void:
	var ingredient_pool: Array[String] = [ITEM_SPINACH, ITEM_POTATO_SLICE, ITEM_TOFU_PUFF]
	ingredient_pool.shuffle()

	var ingredient_count := randi_range(1, 2)
	ingredients.clear()

	for i in range(ingredient_count):
		var ingredient_id: String = ingredient_pool[i]
		var quantity := randi_range(1, 2)
		ingredients[ingredient_id] = quantity

func mark_checkout_started() -> void:
	current_state = CustomerState.ORDER_NEGOTIATING
	print("Customer entered ORDER_NEGOTIATING state.")

func mark_back_to_counter_waiting() -> void:
	current_state = CustomerState.AT_COUNTER
	print("Customer returned to AT_COUNTER state.")

func mark_payment_completed(quoted_price: int, true_price: int) -> void:
	is_checked_out = true
	paid_price = quoted_price
	true_price_at_checkout = true_price
	price_reaction_result = "accept"
	print("Customer payment completed. Paid: ", quoted_price, " True price: ", true_price)

func start_waiting_for_food(main_food_cooking: bool, ingredient_cooking: bool) -> void:
	is_waiting_for_food = true
	is_ready_for_delivery = false
	is_waiting_after_checkout = true
	order_served = false

	delivery_patience_current = delivery_patience_max

	needs_main_food_cooking = main_food_cooking
	needs_ingredient_cooking = ingredient_cooking

	print("Customer started waiting for food. main_food_cooking=", main_food_cooking, " ingredient_cooking=", ingredient_cooking)

func mark_food_ready() -> void:
	is_ready_for_delivery = true
	print("Customer food is ready for delivery.")

func mark_order_served() -> void:
	order_served = true
	is_waiting_after_checkout = false
	is_waiting_for_food = false
	is_ready_for_delivery = false
	print("Customer order served.")

func can_be_delivered() -> bool:
	return is_ready_for_delivery

func set_ingredients(new_ingredients: Dictionary) -> void:
	ingredients = new_ingredients

func has_any_ingredients() -> bool:
	return ingredients.size() > 0

func get_total_item_count() -> int:
	var total := 0

	for ingredient_id in ingredients.keys():
		total += int(ingredients[ingredient_id])

	return total

func get_order_price() -> int:
	var price := get_total_item_count()

	if has_main_food():
		price += 1

	return price

func get_paid_price() -> int:
	return paid_price

func get_true_price_at_checkout() -> int:
	return true_price_at_checkout

func reset_patience() -> void:
	counter_patience_current = counter_patience_max
	delivery_patience_current = delivery_patience_max

func get_display_patience_current() -> float:
	if is_waiting_after_checkout and not order_served:
		return delivery_patience_current
	return counter_patience_current

func get_display_patience_max() -> float:
	if is_waiting_after_checkout and not order_served:
		return delivery_patience_max
	return counter_patience_max

func get_pending_order_summary() -> String:
	var patience_text := "%d/%d" % [int(ceil(delivery_patience_current)), int(delivery_patience_max)]
	return TextDB.get_text("UI_PENDING_ORDER_SUMMARY") % [
		get_order_name(),
		get_main_food(),
		get_ingredients_text(),
		patience_text
	]

func get_order_name() -> String:
	return TextDB.get_text(order_name_key)

func get_main_food() -> String:
	return TextDB.get_item_name(main_food_id)

func get_main_food_id() -> String:
	return main_food_id

func has_main_food() -> bool:
	return main_food_id != ITEM_NONE

func get_needs_waiting() -> bool:
	return needs_waiting

func get_ingredients() -> Dictionary:
	return ingredients

func get_ingredients_text() -> String:
	var parts: Array[String] = []

	for ingredient_id in ingredients.keys():
		parts.append(
			TextDB.get_text("UI_ITEM_COUNT") % [
				TextDB.get_item_name(str(ingredient_id)),
				int(ingredients[ingredient_id])
			]
		)

	return ", ".join(parts)

func setup_special_customer(special_type: String, display_name: String) -> void:
	is_special_customer = true
	special_customer_type = special_type
	special_customer_name = display_name
	special_result_recorded = false

	modulate = Color(1.0, 0.92, 0.65, 1.0)

	_create_or_update_special_badge()

	print("This customer is SPECIAL: ", get_customer_display_name(), " / type: ", get_customer_type())

func clear_special_customer() -> void:
	is_special_customer = false
	special_customer_type = ""
	special_customer_name = ""
	special_result_recorded = false

	modulate = Color(1.0, 1.0, 1.0, 1.0)

	var badge = get_node_or_null("SpecialBadgeLabel")
	if badge:
		badge.queue_free()

func _create_or_update_special_badge() -> void:
	var badge = get_node_or_null("SpecialBadgeLabel")

	if badge == null:
		badge = Label.new()
		badge.name = "SpecialBadgeLabel"
		add_child(badge)

	badge.text = "★ %s" % special_customer_name
	badge.position = Vector2(-28, -52)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.size = Vector2(56, 20)
	badge.z_index = 20

	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", Color(1.0, 0.95, 0.35, 1.0))
	badge.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	badge.add_theme_constant_override("shadow_offset_x", 1)
	badge.add_theme_constant_override("shadow_offset_y", 1)

	badge.visible = true

func get_customer_group() -> String:
	if is_special_customer:
		return "special"

	return "normal"


func get_customer_type() -> String:
	if is_special_customer:
		if special_customer_type != "":
			return special_customer_type

		return "special_unknown"

	return "normal_default"


func get_customer_display_name() -> String:
	if is_special_customer:
		if special_customer_name != "":
			return special_customer_name

		return "特殊客人"

	return "普通客人"
