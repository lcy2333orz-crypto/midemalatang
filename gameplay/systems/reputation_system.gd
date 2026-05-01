class_name ReputationSystem
extends RefCounted

const CustomerOrderState := preload("res://gameplay/models/customer_order_state.gd")

var manager = null


func bind(game_manager: Node) -> void:
	manager = game_manager


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	if manager == null or not is_instance_valid(manager):
		warnings.append("ReputationSystem is not bound to a valid GameManager.")
		return warnings

	if manager.get_node_or_null("/root/RunSetupData") == null:
		warnings.append("ReputationSystem: RunSetupData autoload is missing.")

	return warnings


func record_served(customer: Node) -> void:
	if customer == null or not is_instance_valid(customer):
		return

	RunSetupData.record_today_served_customer()

	var delta := get_delta(customer, "served")
	change_shop_reputation(delta, "%s served" % get_customer_group(customer))
	record_special_result(customer, "good")


func record_failed(customer: Node, reason: String = "failed") -> void:
	if customer == null or not is_instance_valid(customer):
		return

	RunSetupData.record_today_failed_customer()

	var delta := get_delta(customer, "failed")
	change_shop_reputation(delta, "%s %s" % [get_customer_group(customer), reason])
	record_special_result(customer, "bad")


func record_special_result(customer: Node, result: String) -> void:
	if customer == null or not is_instance_valid(customer):
		return

	if not CustomerOrderState.is_special_customer(customer):
		return

	if CustomerOrderState.has_recorded_special_result(customer):
		return

	var special_type: String = CustomerOrderState.get_special_customer_type(customer)
	var special_name: String = CustomerOrderState.get_special_customer_name(customer)

	var gift_data := RunSetupData.add_pending_gift(
		special_type,
		special_name,
		result
	)

	var result_data := {
		"type": special_type,
		"name": special_name,
		"result": result,
		"gift_id": str(gift_data.get("gift_id", ""))
	}

	RunSetupData.today_special_customer_results.append(result_data)

	CustomerOrderState.set_special_result_recorded(customer, true)

	print("Recorded special customer result: ", result_data)
	print("Special customer left an echo: ", gift_data)


func get_customer_group(customer: Node) -> String:
	if customer == null or not is_instance_valid(customer):
		return "invalid"

	if customer.has_method("get_customer_group"):
		return customer.get_customer_group()

	if CustomerOrderState.is_special_customer(customer):
		return "special"

	return "normal"


func get_customer_type(customer: Node) -> String:
	if customer == null or not is_instance_valid(customer):
		return "invalid"

	if customer.has_method("get_customer_type"):
		return customer.get_customer_type()

	if CustomerOrderState.is_special_customer(customer):
		return CustomerOrderState.get_special_customer_type(customer)

	return "normal_default"


func get_delta(customer: Node, event_name: String) -> int:
	var group := get_customer_group(customer)
	var customer_type := get_customer_type(customer)

	if event_name == "served":
		if group == "special":
			return 3

		return 1

	if event_name == "failed":
		if group == "special":
			return -5

		return -2

	print("Unknown reputation event: ", event_name, " | group: ", group, " | type: ", customer_type)
	return 0


func change_shop_reputation(delta: int, reason: String = "") -> void:
	var old_value: int = RunSetupData.shop_reputation
	RunSetupData.shop_reputation = clamp(RunSetupData.shop_reputation + delta, 0, 100)

	var actual_delta: int = RunSetupData.shop_reputation - old_value
	RunSetupData.today_reputation_delta += actual_delta

	print("Reputation changed: ", old_value, " -> ", RunSetupData.shop_reputation, " | delta: ", actual_delta, " | reason: ", reason)

	manager.refresh_money_and_reputation_ui()


func change(delta: int, reason: String = "") -> void:
	change_shop_reputation(delta, reason)
