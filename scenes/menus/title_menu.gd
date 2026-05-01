extends Control

@onready var title_label: Label = $TitleLabel
@onready var start_button: Button = $MenuBox/StartButton
@onready var settings_button: Button = $MenuBox/SettingsButton
@onready var credits_button: Button = $MenuBox/CreditsButton
@onready var quit_button: Button = $MenuBox/QuitButton
@onready var message_label: Label = $MessageLabel

func _ready() -> void:
	start_button.pressed.connect(_on_start_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	credits_button.pressed.connect(_on_credits_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

	title_label.text = TextDB.get_text("UI_GAME_TITLE")
	start_button.text = TextDB.get_text("UI_TITLE_START")
	settings_button.text = TextDB.get_text("UI_TITLE_SETTINGS")
	credits_button.text = TextDB.get_text("UI_TITLE_CREDITS")
	quit_button.text = TextDB.get_text("UI_TITLE_QUIT")

	message_label.text = ""

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/home_menu.tscn")

func _on_settings_button_pressed() -> void:
	message_label.text = TextDB.get_text("UI_TITLE_SETTINGS_NOT_READY")

func _on_credits_button_pressed() -> void:
	message_label.text = TextDB.get_text("UI_TITLE_CREDITS_NOT_READY")

func _on_quit_button_pressed() -> void:
	get_tree().quit()
