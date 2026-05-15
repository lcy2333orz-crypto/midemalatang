class_name RunSettlementState
extends RefCounted

const VALID_VIEW_MODES = ["day", "run"]
const RUN_SUMMARY_REQUIRED_FIELDS = [
	"total_days",
	"today_gross_income",
	"today_expense",
	"today_net_income",
	"run_gross_income",
	"run_expense",
	"run_net_income",
	"current_money",
	"cooked_stock_text",
	"raw_stock_text",
	"today_reputation_delta",
	"shop_reputation"
]

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
	elif settlement_view_mode == "run":
		for field_name in RUN_SUMMARY_REQUIRED_FIELDS:
			if not last_run_summary.has(field_name):
				warnings.append("RunSettlementState: run summary missing field: " + str(field_name))

	return warnings
