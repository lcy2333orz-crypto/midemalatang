class_name RestaurantUI
extends CanvasLayer

var status_label: Label
var orders_bar: HBoxContainer
var time_label: Label
var prompt_label: Label
var hand_label: Label
var toast_label: Label
var tutorial_panel: Panel
var tutorial_label: Label
var toast_token: int = 0


func _ready() -> void:
	add_to_group("game_ui")
	_ensure_widgets()


func update_status(text: String) -> void:
	_ensure_widgets()
	status_label.text = text
	status_label.visible = false


func update_time(seconds_remaining: float) -> void:
	_ensure_widgets()
	var display_seconds: int = max(0, int(ceil(seconds_remaining)))
	time_label.text = "剩余 %d 秒" % display_seconds


func update_time_text(text: String) -> void:
	_ensure_widgets()
	time_label.text = text


func update_orders(text: String) -> void:
	var card_texts: Array[String] = []
	if text.strip_edges() != "":
		card_texts.append(text)
	update_order_cards(card_texts)


func update_order_cards(card_texts: Array[String]) -> void:
	_ensure_widgets()
	for child in orders_bar.get_children():
		child.queue_free()

	for card_text in card_texts:
		orders_bar.add_child(_create_order_card(card_text))


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
	hand_label.text = hand_text
	hand_label.visible = false


func hide_hand_state() -> void:
	_ensure_widgets()
	hand_label.visible = false
	hand_label.text = ""


func show_toast(text: String, seconds: float = 1.8) -> void:
	_ensure_widgets()
	toast_token += 1
	var current_token: int = toast_token
	toast_label.text = text
	toast_label.visible = text.strip_edges() != ""
	if toast_label.visible:
		get_tree().create_timer(seconds).timeout.connect(_hide_toast.bind(current_token))


func show_tutorial_text(text: String) -> void:
	_ensure_widgets()
	tutorial_label.text = text
	tutorial_panel.visible = text.strip_edges() != ""


func hide_tutorial_text() -> void:
	_ensure_widgets()
	tutorial_label.text = ""
	tutorial_panel.visible = false


func _hide_toast(token: int) -> void:
	if token != toast_token:
		return
	if toast_label == null:
		return
	toast_label.visible = false
	toast_label.text = ""


func _ensure_widgets() -> void:
	if status_label != null:
		return

	status_label = Label.new()
	status_label.name = "RestaurantStatusLabel"
	status_label.visible = false
	status_label.position = Vector2(8, 132)
	status_label.size = Vector2(520, 50)
	status_label.add_theme_font_size_override("font_size", 15)
	add_child(status_label)

	orders_bar = HBoxContainer.new()
	orders_bar.name = "RestaurantOrdersBar"
	orders_bar.position = Vector2(8, 8)
	orders_bar.size = Vector2(764, 124)
	orders_bar.add_theme_constant_override("separation", 8)
	add_child(orders_bar)

	time_label = Label.new()
	time_label.name = "TimeLabel"
	time_label.position = Vector2(780, 8)
	time_label.size = Vector2(168, 34)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 20)
	time_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.72, 1.0))
	time_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 1.0))
	time_label.add_theme_constant_override("outline_size", 3)
	add_child(time_label)

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
	hand_label.visible = false
	hand_label.position = Vector2(18, 72)
	hand_label.size = Vector2(360, 30)
	hand_label.add_theme_font_size_override("font_size", 15)
	add_child(hand_label)

	toast_label = Label.new()
	toast_label.name = "ToastLabel"
	toast_label.visible = false
	toast_label.position = Vector2(260, 430)
	toast_label.size = Vector2(440, 42)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 20)
	toast_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.72, 1.0))
	toast_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 1.0))
	toast_label.add_theme_constant_override("outline_size", 4)
	add_child(toast_label)

	tutorial_panel = Panel.new()
	tutorial_panel.name = "TutorialPanel"
	tutorial_panel.visible = false
	tutorial_panel.position = Vector2(18, 390)
	tutorial_panel.size = Vector2(470, 118)
	var tutorial_style: StyleBoxFlat = StyleBoxFlat.new()
	tutorial_style.bg_color = Color(0.0, 0.0, 0.0, 0.72)
	tutorial_style.border_color = Color(1.0, 0.92, 0.55, 0.9)
	tutorial_style.border_width_left = 2
	tutorial_style.border_width_top = 2
	tutorial_style.border_width_right = 2
	tutorial_style.border_width_bottom = 2
	tutorial_style.corner_radius_top_left = 6
	tutorial_style.corner_radius_top_right = 6
	tutorial_style.corner_radius_bottom_left = 6
	tutorial_style.corner_radius_bottom_right = 6
	tutorial_panel.add_theme_stylebox_override("panel", tutorial_style)
	add_child(tutorial_panel)

	tutorial_label = Label.new()
	tutorial_label.name = "TutorialLabel"
	tutorial_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	tutorial_label.offset_left = 14
	tutorial_label.offset_top = 10
	tutorial_label.offset_right = -14
	tutorial_label.offset_bottom = -10
	tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tutorial_label.add_theme_font_size_override("font_size", 18)
	tutorial_label.add_theme_color_override("font_color", Color.WHITE)
	tutorial_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	tutorial_label.add_theme_constant_override("outline_size", 3)
	tutorial_panel.add_child(tutorial_label)


func _create_order_card(card_text: String) -> Panel:
	var card: Panel = Panel.new()
	card.custom_minimum_size = Vector2(120, 146)

	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 6
	box.offset_top = 4
	box.offset_right = -6
	box.offset_bottom = -5
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)

	var lines: PackedStringArray = card_text.split("\n", false)
	var label_lines: Array[String] = []
	var patience_percent: float = 0.0
	for i in range(lines.size()):
		if i == lines.size() - 1:
			patience_percent = _extract_percent_value(str(lines[i]))
		else:
			label_lines.append(lines[i])

	var info_label: Label = Label.new()
	info_label.text = "\n".join(label_lines)
	info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 11)
	box.add_child(info_label)

	var patience_bar: ProgressBar = ProgressBar.new()
	patience_bar.min_value = 0.0
	patience_bar.max_value = 100.0
	patience_bar.value = clamp(patience_percent, 0.0, 100.0)
	patience_bar.show_percentage = false
	patience_bar.custom_minimum_size = Vector2(0, 10)
	box.add_child(patience_bar)

	return card


func _extract_percent_value(text: String) -> float:
	var number_text: String = ""
	for i in range(text.length()):
		var ch: String = text.substr(i, 1)
		if (ch >= "0" and ch <= "9") or ch == ".":
			number_text += ch
	if number_text == "":
		return 0.0
	return float(number_text)
