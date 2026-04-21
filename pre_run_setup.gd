extends Node2D

@onready var title_label: Label = $CanvasLayer/TitleLabel
@onready var stage_info_label: Label = $CanvasLayer/StageInfoLabel
@onready var layout_info_label: Label = $CanvasLayer/LayoutInfoLabel
@onready var confirm_button: Button = $CanvasLayer/ConfirmButton

func _ready() -> void:
	title_label.text = "开业前整备"
	confirm_button.text = "确认开业"
	confirm_button.pressed.connect(_on_confirm_button_pressed)

	_refresh_stage_info()
	_prepare_default_layout_preview()

func _refresh_stage_info() -> void:
	var stage_id := RunSetupData.selected_stage_id

	if stage_id == "":
		stage_info_label.text = "当前关卡：未选择"
	else:
		stage_info_label.text = "当前关卡：%s" % stage_id

func _prepare_default_layout_preview() -> void:
	var lines: Array[String] = []

	lines.append("当前为占位版整备。")
	lines.append("这一步先不手动摆放设施，而是进入关卡时写入一套默认布局。")
	lines.append("后面再把这里升级成真正的摆放界面。")
	lines.append("")
	lines.append("默认布局预览：")
	lines.append("counter -> slot_a")
	lines.append("delivery -> slot_b")
	lines.append("storage -> slot_c")
	lines.append("cooker_1 -> slot_d")

	if ProgressData.has_second_cooker:
		lines.append("cooker_2 -> slot_e")
		lines.append("emergency_shop -> slot_f")
	else:
		lines.append("emergency_shop -> slot_e")

	layout_info_label.text = "\n".join(lines)

func _on_confirm_button_pressed() -> void:
	_write_default_layout_for_current_stage()
	get_tree().change_scene_to_file("res://main.tscn")

func _write_default_layout_for_current_stage() -> void:
	RunSetupData.station_layout["counter"] = "slot_a"
	RunSetupData.station_layout["delivery"] = "slot_b"
	RunSetupData.station_layout["storage"] = "slot_c"
	RunSetupData.station_layout["cooker_1"] = "slot_d"

	if ProgressData.has_second_cooker:
		RunSetupData.station_layout["cooker_2"] = "slot_e"
		RunSetupData.station_layout["emergency_shop"] = "slot_f"
	else:
		RunSetupData.station_layout["cooker_2"] = ""
		RunSetupData.station_layout["emergency_shop"] = "slot_e"

	RunSetupData.order_panel_blocked_for_this_run = false
	RunSetupData.layout_locked_for_this_run = false

	print("=== 本局整备完成 ===")
	print("Selected stage: ", RunSetupData.selected_stage_id)
	print("Station layout: ", RunSetupData.station_layout)
