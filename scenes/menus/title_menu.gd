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

	title_label.text = "麻辣烫"
	start_button.text = "开始"
	settings_button.text = "设置"
	credits_button.text = "制作名单"
	quit_button.text = "退出"

	message_label.text = ""

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/home_menu.tscn")

func _on_settings_button_pressed() -> void:
	message_label.text = "设置暂未开放"

func _on_credits_button_pressed() -> void:
	message_label.text = "制作名单暂未开放"

func _on_quit_button_pressed() -> void:
	get_tree().quit()
