class_name SettlementBuilder
extends RefCounted

var manager = null


func bind(game_manager: Node) -> void:
	manager = game_manager


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	if manager == null or not is_instance_valid(manager):
		warnings.append("SettlementBuilder is not bound to a valid GameManager.")

	return warnings


func build_day_summary(input: Dictionary) -> Dictionary:
	return {
		"day_index": RunSetupData.current_day_in_run,
		"total_days": RunSetupData.total_days_in_run,
		"today_gross_income": int(input.get("today_gross_income", 0)),
		"today_expense": int(input.get("today_expense", 0)),
		"today_net_income": int(input.get("today_net_income", 0)),
		"run_gross_income": int(input.get("run_gross_income", 0)),
		"run_expense": int(input.get("run_expense", 0)),
		"run_net_income": int(input.get("run_net_income", 0)),
		"current_money": int(input.get("current_money", 0)),
		"cooked_stock_text": str(input.get("cooked_stock_text", "")),
		"raw_stock_text": str(input.get("raw_stock_text", "")),
		"cooked_stock_data": input.get("cooked_stock_data", {}),
		"raw_stock_data": input.get("raw_stock_data", {}),
		"staple_stock_data": input.get("staple_stock_data", {}),
		"discarded_staple_food": input.get("discarded_staple_food", {}),
		"today_reputation_delta": RunSetupData.today_reputation_delta,
		"shop_reputation": RunSetupData.shop_reputation,
		"today_echo_lines": RunSetupData.get_today_stall_echo_lines(),
		"cooked_stock_discarded": true
	}


func build_run_summary(input: Dictionary) -> Dictionary:
	return {
		"total_days": RunSetupData.total_days_in_run,
		"today_gross_income": int(input.get("today_gross_income", 0)),
		"today_expense": int(input.get("today_expense", 0)),
		"today_net_income": int(input.get("today_net_income", 0)),
		"run_gross_income": int(input.get("run_gross_income", 0)),
		"run_expense": int(input.get("run_expense", 0)),
		"run_net_income": int(input.get("run_net_income", 0)),
		"current_money": int(input.get("current_money", 0)),
		"cooked_stock_text": str(input.get("cooked_stock_text", "")),
		"raw_stock_text": str(input.get("raw_stock_text", "")),
		"cooked_stock_data": input.get("cooked_stock_data", {}),
		"raw_stock_data": input.get("raw_stock_data", {}),
		"staple_stock_data": input.get("staple_stock_data", {}),
		"today_reputation_delta": RunSetupData.today_reputation_delta,
		"shop_reputation": RunSetupData.shop_reputation,
		"today_echo_lines": RunSetupData.get_today_stall_echo_lines(),
		"cooked_stock_discarded": true
	}
