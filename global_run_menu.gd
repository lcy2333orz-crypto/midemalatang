extends CanvasLayer

var root: Control = null
var bg: ColorRect = null
var panel: Panel = null
var title_label: Label = null
var buff_label: Label = null
var close_button: Button = null
var abandon_button: Button = null


func _ready() -> void:
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)

	_create_menu()
	_hide_menu_without_unpausing()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_TAB:
			toggle_menu()
			get_viewport().set_input_as_handled()


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
	panel.size = Vector2(520, 360)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "当前效果"
	title_label.position = Vector2(24, 22)
	title_label.size = Vector2(472, 36)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	panel.add_child(title_label)

	buff_label = Label.new()
	buff_label.name = "BuffLabel"
	buff_label.position = Vector2(34, 76)
	buff_label.size = Vector2(452, 190)
	buff_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	buff_label.add_theme_font_size_override("font_size", 15)
	panel.add_child(buff_label)

	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "关闭面板"
	close_button.position = Vector2(34, 292)
	close_button.size = Vector2(180, 44)
	close_button.process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(close_menu)
	panel.add_child(close_button)

	abandon_button = Button.new()
	abandon_button.name = "AbandonButton"
	abandon_button.text = "放弃本局，返回主页"
	abandon_button.position = Vector2(236, 292)
	abandon_button.size = Vector2(250, 44)
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

	_position_menu()
	_refresh_buff_text()

	root.visible = true
	get_tree().paused = true

	close_button.grab_focus()

	print("Global run menu opened.")


func close_menu() -> void:
	if root == null:
		return

	root.visible = false
	get_tree().paused = false

	print("Global run menu closed.")


func _hide_menu_without_unpausing() -> void:
	if root != null:
		root.visible = false


func _refresh_buff_text() -> void:
	if buff_label == null:
		return

	var lines := EffectManager.get_active_effect_lines()
	lines.append("")
	lines.append("按 Tab 或点击按钮关闭。")

	buff_label.text = "\n".join(lines)


func _on_abandon_button_pressed() -> void:
	get_tree().paused = false

	if root != null:
		root.visible = false

	RunSetupData.reset_run_setup()
	get_tree().change_scene_to_file("res://home_menu.tscn")
