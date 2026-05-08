class_name EconomySystem
extends RefCounted

var manager = null

var money: int = 0
var round_income: int = 0
var round_gross_income: int = 0
var round_expense: int = 0
var today_income: int = 0
var today_gross_income: int = 0
var today_expense: int = 0


func bind(game_manager: Node) -> void:
	manager = game_manager


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	if manager == null or not is_instance_valid(manager):
		warnings.append("EconomySystem is not bound to a valid GameManager.")

	return warnings


func load_run_state() -> void:
	var money_state: Dictionary = RunSetupData.get_money_state()
	money = int(money_state.get("run_money", 0))
	round_income = int(money_state.get("run_total_income", 0))
	round_gross_income = int(money_state.get("run_gross_income", 0))
	round_expense = int(money_state.get("run_total_expense", 0))
	today_income = 0
	today_gross_income = 0
	today_expense = 0
	_sync_manager_fields()


func add_money(amount: int) -> void:
	if amount <= 0:
		return

	money += amount
	today_gross_income += amount
	round_gross_income += amount
	today_income += amount
	round_income += amount

	_sync_runtime_state()
	_refresh_ui()

	print("Money earned: ", amount)
	print("Current money: ", money)


func spend_money(amount: int) -> bool:
	if amount <= 0:
		return true

	if money < amount:
		print("Not enough money. Need: ", amount, " Current: ", money)
		return false

	money -= amount
	today_expense += amount
	round_expense += amount
	today_income -= amount
	round_income -= amount

	_sync_runtime_state()
	_refresh_ui()

	print("Money spent: ", amount)
	print("Current money: ", money)

	return true


func get_today_income() -> int:
	return today_income


func get_run_income() -> int:
	return round_income


func get_waste_value() -> int:
	var waste: int = 0

	for ingredient_name in manager.raw_stock.keys():
		waste += int(manager.raw_stock.get(ingredient_name, 0))

	for ingredient_name in manager.cooked_stock.keys():
		waste += int(manager.cooked_stock.get(ingredient_name, 0))

	return waste


func get_round_profit() -> int:
	return round_income - get_waste_value()


func print_round_summary() -> void:
	print("=== Run Summary ===")
	print("Today income: ", today_income)
	print("Round income: ", round_income)
	print("Waste value: ", get_waste_value())
	print("Round profit: ", get_round_profit())
	print("Current money: ", money)
	print("Remaining cooked stock: ", manager.cooked_stock)
	print("Remaining raw stock: ", manager.raw_stock)


func get_summary_input_fields() -> Dictionary:
	return {
		"today_gross_income": today_gross_income,
		"today_expense": today_expense,
		"today_net_income": today_income,
		"run_gross_income": round_gross_income,
		"run_expense": round_expense,
		"run_net_income": round_income,
		"current_money": money
	}


func _sync_runtime_state() -> void:
	_sync_manager_fields()
	RunSetupData.set_money_state(money, round_income, round_gross_income, round_expense)


func _sync_manager_fields() -> void:
	if manager == null or not is_instance_valid(manager):
		return

	manager.money = money
	manager.round_income = round_income
	manager.round_gross_income = round_gross_income
	manager.round_expense = round_expense
	manager.today_income = today_income
	manager.today_gross_income = today_gross_income
	manager.today_expense = today_expense


func _refresh_ui() -> void:
	if manager == null or not is_instance_valid(manager):
		return

	if manager.gameplay_hud_system != null:
		manager.gameplay_hud_system.refresh_money_and_reputation_ui()
