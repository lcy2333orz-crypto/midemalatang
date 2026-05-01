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


func build_day_summary(
	remaining_cooked_stock: Dictionary,
	remaining_raw_stock: Dictionary,
	remaining_staple_stock: Dictionary,
	discarded_staple_food: Dictionary
) -> Dictionary:
	if manager == null or not is_instance_valid(manager):
		return {}

	return {
		"day_index": RunSetupData.current_day_in_run,
		"total_days": RunSetupData.total_days_in_run,
		"today_gross_income": manager.today_gross_income,
		"today_expense": manager.today_expense,
		"today_net_income": manager.today_income,
		"run_gross_income": manager.round_gross_income,
		"run_expense": manager.round_expense,
		"run_net_income": manager.round_income,
		"current_money": manager.money,
		"cooked_stock_text": manager.get_cooked_stock_text(),
		"raw_stock_text": "%s\nÃ¤Â¸Â»Ã©Â£Å¸Ã¥Âºâ€œÃ¥Â­ËœÃ¯Â¼Å¡%s" % [
			manager.get_raw_stock_text(),
			manager.get_staple_stock_text()
		],
		"cooked_stock_data": remaining_cooked_stock,
		"raw_stock_data": remaining_raw_stock,
		"staple_stock_data": remaining_staple_stock,
		"discarded_staple_food": discarded_staple_food,
		"today_reputation_delta": RunSetupData.today_reputation_delta,
		"shop_reputation": RunSetupData.shop_reputation,
		"today_echo_lines": RunSetupData.get_today_stall_echo_lines(),
		"cooked_stock_discarded": true
	}


func build_run_summary(
	remaining_cooked_stock: Dictionary,
	remaining_raw_stock: Dictionary,
	remaining_staple_stock: Dictionary
) -> Dictionary:
	if manager == null or not is_instance_valid(manager):
		return {}

	return {
		"total_days": RunSetupData.total_days_in_run,
		"today_gross_income": manager.today_gross_income,
		"today_expense": manager.today_expense,
		"today_net_income": manager.today_income,
		"run_gross_income": manager.round_gross_income,
		"run_expense": manager.round_expense,
		"run_net_income": manager.round_income,
		"current_money": manager.money,
		"cooked_stock_text": manager.get_cooked_stock_text(),
		"raw_stock_text": "%s\nÃ¤Â¸Â»Ã©Â£Å¸Ã¥Âºâ€œÃ¥Â­ËœÃ¯Â¼Å¡%s" % [
			manager.get_raw_stock_text(),
			manager.get_staple_stock_text()
		],
		"cooked_stock_data": remaining_cooked_stock,
		"raw_stock_data": remaining_raw_stock,
		"staple_stock_data": remaining_staple_stock,
		"today_reputation_delta": RunSetupData.today_reputation_delta,
		"shop_reputation": RunSetupData.shop_reputation,
		"today_echo_lines": RunSetupData.get_today_stall_echo_lines(),
		"cooked_stock_discarded": true
	}


# TODO: Move day/run summary dictionary construction out of GameManager.
# GameManager should only decide when to finish, then ask this builder for data.
