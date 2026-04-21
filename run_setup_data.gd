extends Node

var selected_stage_id: String = ""
var selected_difficulty_days: int = 7

var order_panel_blocked_for_this_run: bool = false
var layout_locked_for_this_run: bool = false

var pre_open_fan_enabled: bool = false

var available_layout_slots: Array[String] = []
var forced_station_layout: Dictionary = {}

var station_layout: Dictionary = {
	"counter": "",
	"delivery": "",
	"storage": "",
	"cooker_1": "",
	"cooker_2": "",
	"emergency_shop": ""
}

func reset_run_setup() -> void:
	selected_stage_id = ""
	selected_difficulty_days = 7

	order_panel_blocked_for_this_run = false
	layout_locked_for_this_run = false
	pre_open_fan_enabled = false

	available_layout_slots = []
	forced_station_layout = {}

	station_layout = {
		"counter": "",
		"delivery": "",
		"storage": "",
		"cooker_1": "",
		"cooker_2": "",
		"emergency_shop": ""
	}

func setup_stage_run(stage_id: String, difficulty_days: int = 7) -> void:
	reset_run_setup()

	selected_stage_id = stage_id
	selected_difficulty_days = difficulty_days

	_apply_default_stage_rules(stage_id)
	_apply_default_station_layout()

func _apply_default_stage_rules(stage_id: String) -> void:
	match stage_id:
		"stage_1":
			available_layout_slots = ["slot_a", "slot_b", "slot_c", "slot_d", "slot_e", "slot_f"]
			order_panel_blocked_for_this_run = false
			layout_locked_for_this_run = false
			pre_open_fan_enabled = false
		"stage_2":
			available_layout_slots = ["slot_a", "slot_b", "slot_c", "slot_d", "slot_e", "slot_f"]
			order_panel_blocked_for_this_run = false
			layout_locked_for_this_run = false
			pre_open_fan_enabled = false
		_:
			available_layout_slots = ["slot_a", "slot_b", "slot_c", "slot_d", "slot_e", "slot_f"]
			order_panel_blocked_for_this_run = false
			layout_locked_for_this_run = false
			pre_open_fan_enabled = false

func _apply_default_station_layout() -> void:
	station_layout["counter"] = "slot_a"
	station_layout["delivery"] = "slot_b"
	station_layout["storage"] = "slot_c"
	station_layout["cooker_1"] = "slot_d"

	if ProgressData.has_second_cooker:
		station_layout["cooker_2"] = "slot_e"
		station_layout["emergency_shop"] = "slot_f"
	else:
		station_layout["cooker_2"] = ""
		station_layout["emergency_shop"] = "slot_e"
