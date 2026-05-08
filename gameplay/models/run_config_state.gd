class_name RunConfigState
extends RefCounted

var owner = null


func bind(run_setup_data: Node) -> void:
	owner = run_setup_data


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	if owner == null:
		warnings.append("RunConfigState is not bound.")
		return warnings

	if typeof(owner.station_layout) != TYPE_DICTIONARY:
		warnings.append("RunConfigState: station_layout is not a Dictionary.")

	if typeof(owner.basic_ingredient_ids) != TYPE_ARRAY:
		warnings.append("RunConfigState: basic_ingredient_ids is not an Array.")

	if typeof(owner.staple_item_ids) != TYPE_ARRAY:
		warnings.append("RunConfigState: staple_item_ids is not an Array.")

	if typeof(owner.supplier_base_prices) != TYPE_DICTIONARY:
		warnings.append("RunConfigState: supplier_base_prices is not a Dictionary.")

	return warnings


func setup_stage_run(stage_id: String, difficulty_days: int = 7) -> void:
	owner.reset_run_setup()
	owner.selected_stage_id = stage_id
	owner.selected_difficulty_days = difficulty_days
	owner.current_day_in_run = 1
	owner.total_days_in_run = difficulty_days
	apply_default_station_layout()


func apply_default_station_layout() -> void:
	owner.station_layout["counter"] = "slot_a"
	owner.station_layout["cooker_1"] = "slot_b"
	owner.station_layout["delivery"] = "slot_c"
	owner.station_layout["storage"] = "slot_e"

	if ProgressData.has_second_cooker:
		owner.station_layout["cooker_2"] = "slot_d"
		owner.station_layout["emergency_shop"] = "slot_f"
	else:
		owner.station_layout["cooker_2"] = ""
		owner.station_layout["emergency_shop"] = "slot_f"


func get_basic_ingredient_ids() -> Array[String]:
	var result: Array[String] = []

	for item_id in owner.basic_ingredient_ids:
		result.append(str(item_id))

	return result


func get_staple_item_ids() -> Array[String]:
	var result: Array[String] = []

	for item_id in owner.staple_item_ids:
		result.append(str(item_id))

	return result


func get_supplier_order_item_ids() -> Array[String]:
	var result: Array[String] = []

	for item_id in owner.basic_ingredient_ids:
		result.append(str(item_id))

	for item_id in owner.staple_item_ids:
		result.append(str(item_id))

	return result


func get_supplier_package_options() -> Array:
	var result: Array = []

	for package_data in owner.supplier_package_options:
		if typeof(package_data) == TYPE_DICTIONARY:
			result.append(package_data.duplicate(true))

	return result


func is_staple_item(item_id: String) -> bool:
	return owner.staple_item_ids.has(item_id)


func get_supplier_delivery_seconds() -> float:
	return max(float(owner.supplier_delivery_seconds), 0.1)


func get_supplier_base_price(item_id: String) -> float:
	if not owner.supplier_base_prices.has(item_id):
		return 1.0

	return max(float(owner.supplier_base_prices.get(item_id, 1.0)), 0.1)


func get_supplier_order_price(item_id: String, amount: int = 1) -> int:
	if amount <= 0:
		return 0

	var base_price: float = get_supplier_base_price(item_id)
	var multiplier: float = owner.get_current_day_multiplier("supplier_order_price_multiplier", 1.0)
	var total: int = int(ceil(float(amount) * base_price * multiplier))
	return max(total, 1)


func get_supplier_order_price_for_items(items: Dictionary) -> int:
	var total: int = 0

	for item_id in items.keys():
		var amount: int = int(items.get(item_id, 0))

		if amount <= 0:
			continue

		total += get_supplier_order_price(str(item_id), amount)

	return total


func get_neighbor_emergency_price(item_id: String, amount: int = 1) -> int:
	if amount <= 0:
		return 0

	var base_price: float = get_supplier_base_price(item_id)
	var emergency_multiplier: float = float(owner.neighbor_emergency_price_multiplier)
	var day_multiplier: float = owner.get_current_day_multiplier("emergency_shop_price_multiplier", 1.0)
	var raw_total: float = float(amount) * base_price * emergency_multiplier * day_multiplier
	var total: int = int(ceil(raw_total))
	return max(total, 1)


func get_neighbor_emergency_price_for_shortage(shortage: Dictionary) -> int:
	var total: int = 0

	for item_id in shortage.keys():
		var amount: int = int(shortage.get(item_id, 0))

		if amount <= 0:
			continue

		total += get_neighbor_emergency_price(str(item_id), amount)

	return total


func ensure_starting_money_for_new_run() -> void:
	owner._sync_runtime_state_from_fields()

	if owner.current_day_in_run != 1:
		return

	if owner.run_money > 0:
		return

	if owner.run_total_income != 0:
		return

	owner.run_money = int(owner.starting_money)
	owner._sync_runtime_state_from_fields()

	print("Starting money granted: ", owner.starting_money)
