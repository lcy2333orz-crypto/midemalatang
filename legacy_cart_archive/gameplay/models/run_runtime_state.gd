class_name RunRuntimeState
extends RefCounted

var run_money: int = 0
var run_total_income: int = 0
var run_gross_income: int = 0
var run_total_expense: int = 0
var current_raw_stock: Dictionary = {}
var current_cooked_stock: Dictionary = {}
var current_staple_stock: Dictionary = {}


func reset() -> void:
	run_money = 0
	run_total_income = 0
	run_gross_income = 0
	run_total_expense = 0
	current_raw_stock = {}
	current_cooked_stock = {}
	current_staple_stock = {}


func set_money_state(money: int, total_income: int, gross_income: int, total_expense: int) -> void:
	run_money = money
	run_total_income = total_income
	run_gross_income = gross_income
	run_total_expense = total_expense


func get_money_state() -> Dictionary:
	return {
		"run_money": run_money,
		"run_total_income": run_total_income,
		"run_gross_income": run_gross_income,
		"run_total_expense": run_total_expense
	}


func set_stock_state(raw_stock: Dictionary, cooked_stock: Dictionary, staple_stock: Dictionary) -> void:
	current_raw_stock = raw_stock.duplicate(true)
	current_cooked_stock = cooked_stock.duplicate(true)
	current_staple_stock = staple_stock.duplicate(true)


func get_stock_state() -> Dictionary:
	return {
		"current_raw_stock": current_raw_stock.duplicate(true),
		"current_cooked_stock": current_cooked_stock.duplicate(true),
		"current_staple_stock": current_staple_stock.duplicate(true)
	}


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	for money_key in ["run_money", "run_total_income", "run_gross_income", "run_total_expense"]:
		if typeof(get(money_key)) != TYPE_INT:
			warnings.append("RunRuntimeState: %s is not an int." % money_key)

	_append_stock_warnings(warnings, "current_raw_stock", current_raw_stock)
	_append_stock_warnings(warnings, "current_cooked_stock", current_cooked_stock)
	_append_stock_warnings(warnings, "current_staple_stock", current_staple_stock)

	return warnings


func _append_stock_warnings(warnings: Array[String], stock_name: String, stock) -> void:
	if typeof(stock) != TYPE_DICTIONARY:
		warnings.append("RunRuntimeState: %s is not a Dictionary." % stock_name)
		return

	for item_id in stock.keys():
		var amount = stock.get(item_id, 0)
		if typeof(amount) != TYPE_INT:
			warnings.append("RunRuntimeState: %s[%s] is not an int." % [stock_name, str(item_id)])
			continue
		if int(amount) < 0:
			warnings.append("RunRuntimeState: %s[%s] is negative." % [stock_name, str(item_id)])
