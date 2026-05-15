extends Control

@onready var title_label: Label = $TitleLabel
@onready var stage1_button: Button = $MenuBox/Stage1Button
@onready var stage2_button: Button = $MenuBox/Stage2Button
@onready var back_button: Button = $MenuBox/BackButton
@onready var message_label: Label = $MessageLabel

func _ready() -> void:
	stage1_button.pressed.connect(_on_stage1_button_pressed)
	stage2_button.pressed.connect(_on_stage2_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)

	title_label.text = "选择测试场景"
	stage1_button.text = "餐厅灰盒 1"
	stage2_button.text = "餐厅灰盒 2"
	back_button.text = "返回"

	message_label.text = "两个入口当前都进入餐厅灰盒"

func _on_stage1_button_pressed() -> void:
	RestaurantRunState.start_new_run(3)
	get_tree().change_scene_to_file("res://scenes/gameplay/test_restaurant.tscn")

func _on_stage2_button_pressed() -> void:
	RestaurantRunState.start_new_run(3)
	get_tree().change_scene_to_file("res://scenes/gameplay/test_restaurant.tscn")

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/home_menu.tscn")
