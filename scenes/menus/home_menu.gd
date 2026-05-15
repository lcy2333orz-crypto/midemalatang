extends Control

@onready var title_label: Label = $TitleLabel
@onready var stage_select_button: Button = $MenuBox/StageSelectButton
@onready var tutorial_button: Button = $MenuBox/TutorialButton
@onready var notebook_button: Button = $MenuBox/NotebookButton
@onready var map_button: Button = $MenuBox/MapButton
@onready var back_button: Button = $MenuBox/BackButton
@onready var message_label: Label = $MessageLabel

func _ready() -> void:
	stage_select_button.pressed.connect(_on_stage_select_button_pressed)
	tutorial_button.pressed.connect(_on_tutorial_button_pressed)
	notebook_button.pressed.connect(_on_notebook_button_pressed)
	map_button.pressed.connect(_on_map_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)

	title_label.text = ""
	stage_select_button.text = "选择关卡"
	tutorial_button.text = "快速开始"
	notebook_button.text = "手账"
	map_button.text = "地图"
	back_button.text = "返回"

	message_label.text = "当前主线：餐厅灰盒测试"

func _on_stage_select_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/stage_select.tscn")

func _on_tutorial_button_pressed() -> void:
	RestaurantRunState.start_new_run(3)
	get_tree().change_scene_to_file("res://scenes/gameplay/test_restaurant.tscn")

func _on_notebook_button_pressed() -> void:
	message_label.text = "手账暂未开放"

func _on_map_button_pressed() -> void:
	message_label.text = "地图暂未开放"

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/title_menu.tscn")
