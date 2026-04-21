extends Control

@onready var stage1_button: Button = $MenuBox/Stage1Button
@onready var stage2_button: Button = $MenuBox/Stage2Button
@onready var back_button: Button = $MenuBox/BackButton
@onready var message_label: Label = $MessageLabel

func _ready() -> void:
	stage1_button.pressed.connect(_on_stage1_button_pressed)
	stage2_button.pressed.connect(_on_stage2_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)

	message_label.text = "请选择一个关卡。"

func _on_stage1_button_pressed() -> void:
	RunSetupData.setup_stage_run("stage_1", 7)
	get_tree().change_scene_to_file("res://main.tscn")

func _on_stage2_button_pressed() -> void:
	RunSetupData.setup_stage_run("stage_2", 7)
	get_tree().change_scene_to_file("res://main.tscn")

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://home_menu.tscn")
