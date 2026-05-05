class_name RunSettlementState
extends RefCounted

const VALID_VIEW_MODES := ["day", "run"]

var settlement_view_mode: String = "day"
var last_day_summary: Dictionary = {}
var last_run_summary: Dictionary = {}


func reset() -> void:
	settlement_view_mode = "day"
	last_day_summary = {}
	last_run_summary = {}


func set_day_summary(summary: Dictionary) -> void:
	last_day_summary = summary.duplicate(true)
	settlement_view_mode = "day"


func set_run_summary(summary: Dictionary) -> void:
	last_run_summary = summary.duplicate(true)
	settlement_view_mode = "run"


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	if not VALID_VIEW_MODES.has(settlement_view_mode):
		warnings.append("RunSettlementState: settlement_view_mode is invalid.")

	if typeof(last_day_summary) != TYPE_DICTIONARY:
		warnings.append("RunSettlementState: last_day_summary is not a Dictionary.")

	if typeof(last_run_summary) != TYPE_DICTIONARY:
		warnings.append("RunSettlementState: last_run_summary is not a Dictionary.")

	return warnings
