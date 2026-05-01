extends CanvasLayer

var root: Control = null
var bg: ColorRect = null
var panel: Panel = null
var title_label: Label = null
var buff_label: Label = null
var action_container: VBoxContainer = null
var close_button: Button = null
var abandon_button: Button = null

var current_opening_gift_id: String = ""
var current_gift_options: Array = []


func _ready() -> void:
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)

	_create_menu()
	_hide_menu_without_unpausing()


func _input(event: InputEvent) -> void:
	if not _can_open_for_current_scene():
		return

	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_TAB:
			toggle_menu()
			get_viewport().set_input_as_handled()


func _can_open_for_current_scene() -> bool:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return false

	return current_scene.scene_file_path == "res://scenes/gameplay/main.tscn"


func _create_menu() -> void:
	root = Control.new()
	root.name = "GlobalRunMenuRoot"
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	add_child(root)

	bg = ColorRect.new()
	bg.name = "GlobalRunMenuBackground"
	bg.color = Color(0.0, 0.0, 0.0, 0.72)
	bg.process_mode = Node.PROCESS_MODE_ALWAYS
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bg)

	panel = Panel.new()
	panel.name = "GlobalRunMenuPanel"
	panel.size = Vector2(560, 470)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "当前效果与回响"
	title_label.position = Vector2(24, 18)
	title_label.size = Vector2(512, 36)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	panel.add_child(title_label)

	buff_label = Label.new()
	buff_label.name = "BuffLabel"
	buff_label.position = Vector2(34, 66)
	buff_label.size = Vector2(492, 145)
	buff_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	buff_label.add_theme_font_size_override("font_size", 15)
	panel.add_child(buff_label)

	action_container = VBoxContainer.new()
	action_container.name = "ActionContainer"
	action_container.position = Vector2(34, 225)
	action_container.size = Vector2(492, 150)
	action_container.add_theme_constant_override("separation", 8)
	panel.add_child(action_container)

	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "关闭面板"
	close_button.position = Vector2(34, 405)
	close_button.size = Vector2(180, 44)
	close_button.process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(close_menu)
	panel.add_child(close_button)

	abandon_button = Button.new()
	abandon_button.name = "AbandonButton"
	abandon_button.text = "放弃本局，返回主页"
	abandon_button.position = Vector2(250, 405)
	abandon_button.size = Vector2(276, 44)
	abandon_button.process_mode = Node.PROCESS_MODE_ALWAYS
	abandon_button.mouse_filter = Control.MOUSE_FILTER_STOP
	abandon_button.pressed.connect(_on_abandon_button_pressed)
	panel.add_child(abandon_button)

	_position_menu()


func _position_menu() -> void:
	if root == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size

	root.position = Vector2.ZERO
	root.size = viewport_size

	bg.position = Vector2.ZERO
	bg.size = viewport_size

	panel.position = Vector2(
		viewport_size.x * 0.5 - panel.size.x * 0.5,
		viewport_size.y * 0.5 - panel.size.y * 0.5
	)


func toggle_menu() -> void:
	if root == null:
		return

	if root.visible:
		close_menu()
	else:
		open_menu()


func open_menu() -> void:
	if root == null:
		return

	if not _can_open_for_current_scene():
		return

	_position_menu()
	_show_overview()

	root.visible = true
	get_tree().paused = true

	close_button.grab_focus()

	print("Global run menu opened.")


func close_menu() -> void:
	if root == null:
		return

	root.visible = false
	get_tree().paused = false
	current_opening_gift_id = ""
	current_gift_options = []

	print("Global run menu closed.")


func _hide_menu_without_unpausing() -> void:
	if root != null:
		root.visible = false


func _show_overview() -> void:
	current_opening_gift_id = ""
	current_gift_options = []

	title_label.text = "当前效果与回响"

	var lines: Array[String] = []

	var effect_lines := EffectManager.get_active_effect_lines()
	for line in effect_lines:
		lines.append(line)

	lines.append("")
	lines.append("----------------")

	var gift_lines := RunSetupData.get_pending_gift_lines()
	for line in gift_lines:
		lines.append(line)

	lines.append("")
	lines.append("可以打开特殊客人的回响，选择其中一种影响。")

	buff_label.text = "\n".join(lines)

	_refresh_overview_actions()


func _refresh_overview_actions() -> void:
	_clear_action_container()

	var unopened_gifts := RunSetupData.get_unopened_pending_gifts()

	if unopened_gifts.is_empty():
		var empty_label := Label.new()
		empty_label.text = "当前没有可以打开的回响。"
		empty_label.size = Vector2(492, 34)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		action_container.add_child(empty_label)
		return

	for gift_data in unopened_gifts:
		if typeof(gift_data) != TYPE_DICTIONARY:
			continue

		var gift_id := str(gift_data.get("gift_id", ""))
		var display_name := str(gift_data.get("display_name", "特殊客人的回响"))

		var button := Button.new()
		button.text = "打开：%s" % display_name
		button.custom_minimum_size = Vector2(492, 36)
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.pressed.connect(_on_open_gift_pressed.bind(gift_id))

		action_container.add_child(button)


func _on_open_gift_pressed(gift_id: String) -> void:
	var gift_data := RunSetupData.get_unopened_gift_by_id(gift_id)

	if gift_data.is_empty():
		_show_overview()
		return

	current_opening_gift_id = gift_id

	var saved_options := RunSetupData.get_gift_current_options(gift_id)

	if saved_options.is_empty():
		saved_options = EffectManager.get_card_options_for_special_echo(gift_data)
		RunSetupData.set_gift_current_options(gift_id, saved_options)

	current_gift_options = saved_options

	_show_gift_choice(gift_data)


func _show_gift_choice(gift_data: Dictionary) -> void:
	_clear_action_container()

	var display_name := str(gift_data.get("display_name", "特殊客人的回响"))

	title_label.text = display_name

	buff_label.text = "选择一种回响。\n\n打开后会立刻成为当前效果；今晚不会再重复结算这个回响。"

	for card_data in current_gift_options:
		if typeof(card_data) != TYPE_DICTIONARY:
			continue

		var card_id := str(card_data.get("id", "unknown_card"))
		var card_name := str(card_data.get("name", "未知卡牌"))
		var description := str(card_data.get("description", ""))

		var button := Button.new()
		button.text = card_name

		if description != "":
			button.text += "\n%s" % description

		button.custom_minimum_size = Vector2(492, 44)
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.pressed.connect(_on_choose_gift_card_pressed.bind(current_opening_gift_id, card_id))

		action_container.add_child(button)

	var back_button := Button.new()
	back_button.text = "先不打开"
	back_button.custom_minimum_size = Vector2(492, 36)
	back_button.process_mode = Node.PROCESS_MODE_ALWAYS
	back_button.mouse_filter = Control.MOUSE_FILTER_STOP
	back_button.pressed.connect(_show_overview)
	action_container.add_child(back_button)


func _on_choose_gift_card_pressed(gift_id: String, card_id: String) -> void:
	var gift_data := RunSetupData.get_unopened_gift_by_id(gift_id)

	if gift_data.is_empty():
		_show_overview()
		return

	var card_data := EffectManager.get_card_definition(card_id)

	if card_data.is_empty():
		print("Cannot open echo: missing card definition: ", card_id)
		_show_overview()
		return

	var card_name := str(card_data.get("name", "未知卡牌"))

	RunSetupData.active_effects.append({
		"source": str(gift_data.get("display_name", gift_data.get("source_name", "特殊客人"))),
		"type": "special_echo",
		"result": str(gift_data.get("result", "neutral")),
		"effect_id": card_id,
		"effect": card_name,
		"from_gift_id": gift_id
	})

	RunSetupData.mark_gift_opened(gift_id, card_data)

	print("Opened special echo card: ", card_name, " / id=", card_id)

	_show_overview()


func _clear_action_container() -> void:
	if action_container == null:
		return

	for child in action_container.get_children():
		child.queue_free()


func _on_abandon_button_pressed() -> void:
	get_tree().paused = false

	if root != null:
		root.visible = false

	RunSetupData.reset_run_setup()
	get_tree().change_scene_to_file("res://scenes/menus/home_menu.tscn")
