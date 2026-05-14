class_name RestaurantUI
extends CanvasLayer

var status_label: Label
var orders_label: Label
var prompt_label: Label
var hand_label: Label
var help_label: Label


func _ready() -> void:
	add_to_group("game_ui")
	_ensure_widgets()


func update_status(text: String) -> void:
	_ensure_widgets()
	status_label.text = text


func update_orders(text: String) -> void:
	_ensure_widgets()
	orders_label.text = text


func show_interaction_prompt(prompt_text: String) -> void:
	_ensure_widgets()
	prompt_label.visible = prompt_text.strip_edges() != ""
	prompt_label.text = prompt_text


func hide_interaction_prompt() -> void:
	_ensure_widgets()
	prompt_label.visible = false
	prompt_label.text = ""


func update_hand_state(hand_text: String) -> void:
	_ensure_widgets()
	hand_label.visible = hand_text.strip_edges() != ""
	hand_label.text = hand_text


func hide_hand_state() -> void:
	_ensure_widgets()
	hand_label.visible = false
	hand_label.text = ""


func _ensure_widgets() -> void:
	if status_label != null:
		return

	status_label = Label.new()
	status_label.name = "RestaurantStatusLabel"
	status_label.position = Vector2(18, 122)
	status_label.size = Vector2(520, 54)
	status_label.add_theme_font_size_override("font_size", 15)
	add_child(status_label)

	help_label = Label.new()
	help_label.name = "RestaurantHelpLabel"
	help_label.position = Vector2(18, 10)
	help_label.size = Vector2(610, 106)
	help_label.text = "E: interact\nCounter: press E several times to create order\nWaitingArea: take bowl\nCooker: cook / take cooked bowl\nSauce: add sauce\nPacking/Table/Pickup: finish order"
	help_label.add_theme_font_size_override("font_size", 13)
	help_label.add_theme_color_override("font_color", Color(0.08, 0.07, 0.05, 1.0))
	help_label.add_theme_color_override("font_outline_color", Color(1.0, 0.98, 0.88, 0.95))
	help_label.add_theme_constant_override("outline_size", 2)
	add_child(help_label)

	orders_label = Label.new()
	orders_label.name = "RestaurantOrdersLabel"
	orders_label.position = Vector2(650, 14)
	orders_label.size = Vector2(290, 180)
	orders_label.add_theme_font_size_override("font_size", 13)
	add_child(orders_label)

	prompt_label = Label.new()
	prompt_label.name = "InteractionPromptLabel"
	prompt_label.position = Vector2(320, 500)
	prompt_label.size = Vector2(360, 32)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.72, 1.0))
	prompt_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 1.0))
	prompt_label.add_theme_constant_override("outline_size", 3)
	add_child(prompt_label)

	hand_label = Label.new()
	hand_label.name = "HandStateLabel"
	hand_label.position = Vector2(18, 178)
	hand_label.size = Vector2(360, 30)
	hand_label.add_theme_font_size_override("font_size", 15)
	add_child(hand_label)
