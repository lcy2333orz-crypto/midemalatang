extends Control

@onready var stage_select_button: Button = $MenuBox/StageSelectButton
@onready var notebook_button: Button = $MenuBox/NotebookButton
@onready var map_button: Button = $MenuBox/MapButton
@onready var back_button: Button = $MenuBox/BackButton
@onready var message_label: Label = $MessageLabel

func _ready() -> void:
	stage_select_button.pressed.connect(_on_stage_select_button_pressed)
	notebook_button.pressed.connect(_on_notebook_button_pressed)
	map_button.pressed.connect(_on_map_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)

	message_label.text = "这里是功能主界面。"

func _on_stage_select_button_pressed() -> void:
	get_tree().change_scene_to_file("res://stage_select.tscn")

func _on_notebook_button_pressed() -> void:
	message_label.text = "猫的手账本暂未制作。"

func _on_map_button_pressed() -> void:
	message_label.text = "地图系统暂未制作。"

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://title_menu.tscn")
