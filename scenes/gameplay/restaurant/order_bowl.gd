class_name OrderBowl
extends Node2D

const STAPLE_RAW = "raw"
const STAPLE_PERFECT = "perfect"
const STAPLE_OVERCOOKED = "overcooked"

const STATUS_CUSTOMER_BOWL = "customer_bowl"
const STATUS_WAITING = "waiting"
const STATUS_COOKING = "cooking"
const STATUS_COOKED = "cooked"
const STATUS_OVERCOOKED = "overcooked"
const STATUS_SAUCED = "sauced"
const STATUS_PACKED = "packed"
const STATUS_READY = "ready"
const STATUS_DONE = "done"

@export var order_id: int = 0
@export var staple_type: String = "none"
@export var spice_level: String = "mild"
@export var service_mode: String = "dine_in"
@export var table_id: int = 0
@export var status: String = STATUS_CUSTOMER_BOWL
@export var staple_state: String = STAPLE_RAW

var ingredients: Dictionary = {}
var sauces: Array[String] = []
var is_empty_holder: bool = false
var staple_added: bool = false
var cook_time: float = 0.0
var ingredient_time_required: float = 8.0
var ready_window_seconds: float = 6.0
var staple_perfect_time: float = 8.0
var staple_overcook_time: float = 14.0
var order_patience_max: float = 100.0
var order_patience_current: float = 100.0

var bowl_rect: Polygon2D
var clip_rect: Polygon2D
var label: Label


func _ready() -> void:
	_ensure_visuals()
	refresh_visuals()


func setup_customer_bowl(new_ingredients: Dictionary) -> void:
	order_id = 0
	ingredients = new_ingredients.duplicate(true)
	staple_type = "none"
	spice_level = "mild"
	service_mode = "dine_in"
	table_id = 0
	status = STATUS_CUSTOMER_BOWL
	staple_state = STAPLE_RAW
	is_empty_holder = false
	staple_added = true
	sauces.clear()
	cook_time = 0.0
	order_patience_current = order_patience_max
	_sync_cooking_thresholds()
	refresh_visuals()


func setup_order(
	new_order_id: int,
	new_ingredients: Dictionary,
	new_staple_type: String,
	new_spice_level: String,
	new_service_mode: String,
	new_table_id: int
) -> void:
	order_id = new_order_id
	ingredients = new_ingredients.duplicate(true)
	staple_type = new_staple_type
	spice_level = new_spice_level
	service_mode = new_service_mode
	table_id = new_table_id
	status = STATUS_WAITING
	staple_state = STAPLE_RAW
	is_empty_holder = false
	staple_added = staple_type == "none"
	sauces.clear()
	cook_time = 0.0
	order_patience_current = order_patience_max
	_sync_cooking_thresholds()
	refresh_visuals()


func update_cooking(delta: float) -> void:
	if status != STATUS_COOKING and status != STATUS_COOKED and status != STATUS_OVERCOOKED:
		return

	cook_time += delta

	if cook_time >= staple_overcook_time:
		staple_state = STAPLE_OVERCOOKED
		status = STATUS_OVERCOOKED
	elif cook_time >= ingredient_time_required:
		staple_state = STAPLE_PERFECT
		status = STATUS_COOKED
	else:
		staple_state = STAPLE_RAW

	refresh_visuals()


func update_order_patience(delta: float) -> void:
	if order_id <= 0 or status == STATUS_DONE:
		return
	order_patience_current = max(order_patience_current - delta * 1.25, 0.0)


func get_order_patience_ratio() -> float:
	if order_patience_max <= 0.0:
		return 0.0
	return clamp(order_patience_current / order_patience_max, 0.0, 1.0)


func set_empty_holder_visual() -> void:
	is_empty_holder = true
	refresh_visuals()


func set_full_order_visual() -> void:
	is_empty_holder = false
	refresh_visuals()


func can_leave_cooker() -> bool:
	return status == STATUS_COOKED and not is_overcooked()


func needs_staple() -> bool:
	return staple_type != "none"


func is_staple_ready_for_cooking() -> bool:
	return staple_type == "none" or staple_added


func add_required_staple() -> bool:
	if staple_type == "none":
		staple_added = true
		refresh_visuals()
		return false
	if staple_added:
		return false
	staple_added = true
	refresh_visuals()
	return true


func get_staple_requirement_text() -> String:
	if staple_type == "none":
		return "no staple"
	if staple_added:
		return "staple %s: added" % staple_type
	return "staple %s: missing" % staple_type


func is_overcooked() -> bool:
	return status == STATUS_OVERCOOKED or staple_state == STAPLE_OVERCOOKED


func get_order_status_text() -> String:
	if is_overcooked():
		return "OVER"
	match status:
		STATUS_WAITING:
			return "WAIT"
		STATUS_COOKING:
			return "COOK"
		STATUS_COOKED:
			return "READY"
		STATUS_SAUCED:
			return "READY"
		STATUS_PACKED:
			return "PACKED"
		STATUS_READY:
			return "READY"
		STATUS_DONE:
			return "DONE"
		_:
			return "WAIT"


func get_cooker_timer_text() -> String:
	if is_overcooked():
		return "OVER"
	if status == STATUS_COOKED:
		return "READY %.1fs" % max(staple_overcook_time - cook_time, 0.0)
	if status == STATUS_COOKING:
		return "COOK %.1fs" % max(ingredient_time_required - cook_time, 0.0)
	return "EMPTY"


func _sync_cooking_thresholds() -> void:
	staple_perfect_time = ingredient_time_required
	staple_overcook_time = ingredient_time_required + ready_window_seconds


func add_next_sauce() -> void:
	var sauce_cycle: Array[String] = ["chili", "garlic", "cilantro"]
	for sauce in sauce_cycle:
		if not sauces.has(sauce):
			sauces.append(sauce)
			break

	if not sauces.is_empty() and status == STATUS_COOKED:
		status = STATUS_SAUCED

	refresh_visuals()


func is_sauced() -> bool:
	return not sauces.is_empty()


func mark_packed() -> void:
	if service_mode == "takeout":
		status = STATUS_PACKED
		refresh_visuals()


func mark_ready() -> void:
	status = STATUS_READY
	refresh_visuals()


func mark_done() -> void:
	status = STATUS_DONE
	refresh_visuals()


func get_summary_text() -> String:
	var id_text: String = "C" if order_id <= 0 else "#%03d" % order_id
	if is_empty_holder:
		return "%s empty bowl" % id_text
	return "%s %s %s %s" % [id_text, service_mode, get_staple_requirement_text(), status]


func get_detail_text() -> String:
	var ingredient_parts: Array[String] = []
	for item_id in ingredients.keys():
		ingredient_parts.append("%s x%d" % [str(item_id), int(ingredients[item_id])])
	return "%s | %s | %s | %s" % [
		get_summary_text(),
		", ".join(ingredient_parts),
		spice_level,
		",".join(sauces)
	]


func attach_to_holder(holder: Node2D) -> void:
	if get_parent() != null:
		get_parent().remove_child(self)
	holder.add_child(self)
	position = Vector2(0, -36)
	z_index = 20


func detach_to_world(world_parent: Node, world_position: Vector2) -> void:
	if get_parent() != null:
		get_parent().remove_child(self)
	world_parent.add_child(self)
	global_position = world_position
	z_index = 10


func _ensure_visuals() -> void:
	if bowl_rect == null:
		bowl_rect = Polygon2D.new()
		bowl_rect.name = "BowlVisual"
		bowl_rect.polygon = PackedVector2Array([
			Vector2(-24, -14),
			Vector2(24, -14),
			Vector2(30, 8),
			Vector2(18, 20),
			Vector2(-18, 20),
			Vector2(-30, 8)
		])
		add_child(bowl_rect)

	if clip_rect == null:
		clip_rect = Polygon2D.new()
		clip_rect.name = "OrderClip"
		clip_rect.polygon = PackedVector2Array([
			Vector2(-13, -26),
			Vector2(13, -26),
			Vector2(13, -12),
			Vector2(-13, -12)
		])
		add_child(clip_rect)

	if label == null:
		label = Label.new()
		label.name = "OrderLabel"
		label.position = Vector2(-28, -31)
		label.size = Vector2(56, 22)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color.BLACK)
		add_child(label)


func refresh_visuals() -> void:
	_ensure_visuals()

	if is_empty_holder:
		bowl_rect.color = Color(0.82, 0.82, 0.82, 1.0)
		clip_rect.color = Color(1.0, 0.96, 0.55, 1.0)
		label.text = "E\n%s" % ("C" if order_id <= 0 else str(order_id))
		return

	match status:
		STATUS_CUSTOMER_BOWL:
			bowl_rect.color = Color(0.75, 0.9, 1.0, 1.0)
		STATUS_WAITING:
			bowl_rect.color = Color(1.0, 0.92, 0.45, 1.0)
		STATUS_COOKING:
			bowl_rect.color = Color(1.0, 0.5, 0.25, 1.0)
		STATUS_COOKED:
			bowl_rect.color = Color(0.35, 0.9, 0.45, 1.0)
		STATUS_OVERCOOKED:
			bowl_rect.color = Color(0.16, 0.12, 0.08, 1.0)
		STATUS_SAUCED:
			bowl_rect.color = Color(0.8, 0.45, 0.2, 1.0)
		STATUS_PACKED:
			bowl_rect.color = Color(0.9, 0.9, 0.9, 1.0)
		STATUS_READY:
			bowl_rect.color = Color(0.35, 0.95, 0.95, 1.0)
		STATUS_DONE:
			bowl_rect.color = Color(0.45, 0.45, 0.45, 1.0)
		_:
			bowl_rect.color = Color.WHITE

	match staple_state:
		STAPLE_RAW:
			clip_rect.color = Color(0.95, 0.95, 1.0, 1.0)
		STAPLE_PERFECT:
			clip_rect.color = Color(0.25, 1.0, 0.35, 1.0)
		STAPLE_OVERCOOKED:
			clip_rect.color = Color(0.18, 0.08, 0.04, 1.0)
		_:
			clip_rect.color = Color(0.95, 0.95, 1.0, 1.0)

	label.text = "C" if order_id <= 0 else str(order_id)
