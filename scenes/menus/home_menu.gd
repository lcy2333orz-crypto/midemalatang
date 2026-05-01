extends Control

@onready var title_label: Label = $TitleLabel
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

	title_label.text = ""
	stage_select_button.text = TextDB.get_text("UI_HOME_ENTER_STAGE")
	notebook_button.text = TextDB.get_text("UI_HOME_NOTEBOOK")
	map_button.text = TextDB.get_text("UI_HOME_MAP")
	back_button.text = TextDB.get_text("UI_HOME_BACK")

	message_label.text = TextDB.get_text("UI_HOME_MAIN_HINT")

func _on_stage_select_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/stage_select.tscn")

func _on_notebook_button_pressed() -> void:
	message_label.text = TextDB.get_text("UI_HOME_NOTEBOOK_NOT_READY")

func _on_map_button_pressed() -> void:
	message_label.text = TextDB.get_text("UI_HOME_MAP_NOT_READY")

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/title_menu.tscn")
