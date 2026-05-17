extends Control

const HOME_SCENE_PATH = "res://scenes/menus/home_menu.tscn"
const RESTAURANT_SCENE_PATH = "res://scenes/gameplay/test_restaurant.tscn"

var title_label: Label
var summary_label: Label
var continue_button: Button
var home_button: Button


func _ready() -> void:
	_build_ui()
	_refresh_summary()


func _build_ui() -> void:
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 180
	root.offset_top = 72
	root.offset_right = -180
	root.offset_bottom = -72
	root.add_theme_constant_override("separation", 18)
	add_child(root)

	title_label = Label.new()
	title_label.text = "夜间准备"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	root.add_child(title_label)

	summary_label = Label.new()
	summary_label.text = "夜间升级已改为餐厅原地选择。"
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_label.add_theme_font_size_override("font_size", 20)
	root.add_child(summary_label)

	continue_button = Button.new()
	continue_button.pressed.connect(_on_continue_pressed)
	root.add_child(continue_button)

	home_button = Button.new()
	home_button.text = "返回主页"
	home_button.pressed.connect(_on_home_pressed)
	root.add_child(home_button)


func _refresh_summary() -> void:
	if RestaurantRunState.is_run_complete():
		continue_button.text = "完成本轮，返回主页"
		home_button.visible = false
	else:
		continue_button.text = "返回餐厅"
		home_button.visible = true


func _on_continue_pressed() -> void:
	if RestaurantRunState.is_run_complete():
		get_tree().change_scene_to_file(HOME_SCENE_PATH)
		return
	get_tree().change_scene_to_file(RESTAURANT_SCENE_PATH)


func _on_home_pressed() -> void:
	get_tree().change_scene_to_file(HOME_SCENE_PATH)
