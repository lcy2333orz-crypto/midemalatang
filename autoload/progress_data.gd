extends Node

var has_second_cooker: bool = false
var order_panel_upgrade_level: int = 0

var current_stage_index: int = 1
var layout_freedom_level: int = 0

var last_round_summary: Dictionary = {}

func reset_all_progress() -> void:
	has_second_cooker = false
	order_panel_upgrade_level = 0
	layout_freedom_level = 0
	current_stage_index = 1
	last_round_summary = {}

func unlock_second_cooker() -> void:
	has_second_cooker = true

func upgrade_order_panel() -> void:
	order_panel_upgrade_level = min(order_panel_upgrade_level + 1, 3)

func set_last_round_summary(summary: Dictionary) -> void:
	last_round_summary = summary.duplicate(true)

func clear_last_round_summary() -> void:
	last_round_summary = {}
