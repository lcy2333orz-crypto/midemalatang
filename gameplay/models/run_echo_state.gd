class_name RunEchoState
extends RefCounted

var pending_gifts: Array = []
var opened_gifts: Array = []
var gift_sequence_id: int = 0
var today_customers_served: int = 0
var today_customers_failed: int = 0
var today_special_echo_records: Array = []


func reset_run_state() -> void:
	pending_gifts = []
	opened_gifts = []
	gift_sequence_id = 0
	reset_today_stats()


func reset_today_stats() -> void:
	today_customers_served = 0
	today_customers_failed = 0
	today_special_echo_records = []


func add_pending_gift(source_type: String, source_name: String, result: String, received_day: int) -> Dictionary:
	gift_sequence_id += 1

	var display_name := ""
	var display_kind := ""

	if result == "good":
		display_name = "%s留下的祝愿" % source_name
		display_kind = "blessing"
	elif result == "bad":
		display_name = "%s留下的呸" % source_name
		display_kind = "spit"
	else:
		display_name = "%s留下的回响" % source_name
		display_kind = "echo"

	var gift_data := {
		"gift_id": "gift_%d" % gift_sequence_id,
		"source_type": source_type,
		"source_name": source_name,
		"result": result,
		"gift_type": "special_customer",
		"display_name": display_name,
		"display_kind": display_kind,
		"received_day": received_day,
		"received_order": gift_sequence_id,
		"opened": false,
		"current_options": []
	}

	pending_gifts.append(gift_data)
	record_today_special_echo(display_name, result)

	return gift_data


func get_pending_gift_index_by_id(gift_id: String) -> int:
	for i in range(pending_gifts.size()):
		var gift_data = pending_gifts[i]

		if typeof(gift_data) != TYPE_DICTIONARY:
			continue

		if str(gift_data.get("gift_id", "")) == gift_id:
			return i

	return -1


func get_unopened_gift_by_id(gift_id: String) -> Dictionary:
	var index := get_pending_gift_index_by_id(gift_id)

	if index == -1:
		return {}

	var gift_data: Dictionary = pending_gifts[index]

	if bool(gift_data.get("opened", false)):
		return {}

	return gift_data.duplicate(true)


func is_gift_opened(gift_id: String) -> bool:
	var index := get_pending_gift_index_by_id(gift_id)

	if index == -1:
		return false

	var gift_data: Dictionary = pending_gifts[index]

	return bool(gift_data.get("opened", false))


func get_gift_current_options(gift_id: String) -> Array:
	var index := get_pending_gift_index_by_id(gift_id)

	if index == -1:
		return []

	var gift_data: Dictionary = pending_gifts[index]
	var options = gift_data.get("current_options", [])

	if typeof(options) != TYPE_ARRAY:
		return []

	return options.duplicate(true)


func set_gift_current_options(gift_id: String, options: Array) -> void:
	var index := get_pending_gift_index_by_id(gift_id)

	if index == -1:
		return

	var saved_options: Array = []

	for option in options:
		if typeof(option) == TYPE_DICTIONARY:
			saved_options.append(option.duplicate(true))

	pending_gifts[index]["current_options"] = saved_options


func mark_gift_opened(gift_id: String, chosen_card: Dictionary, opened_day: int) -> Dictionary:
	var index := get_pending_gift_index_by_id(gift_id)

	if index == -1:
		return {}

	var gift_data: Dictionary = pending_gifts[index]

	if bool(gift_data.get("opened", false)):
		return gift_data.duplicate(true)

	gift_data["opened"] = true
	gift_data["opened_day"] = opened_day
	gift_data["chosen_card_id"] = str(chosen_card.get("id", "unknown_card"))
	gift_data["chosen_card_name"] = str(chosen_card.get("name", "未知卡牌"))

	pending_gifts[index] = gift_data
	opened_gifts.append(gift_data.duplicate(true))

	return gift_data.duplicate(true)


func get_unopened_pending_gifts() -> Array:
	var result: Array = []

	for gift_data in pending_gifts:
		if typeof(gift_data) != TYPE_DICTIONARY:
			continue

		if not bool(gift_data.get("opened", false)):
			result.append(gift_data)

	return result


func get_pending_gift_lines() -> Array[String]:
	var lines: Array[String] = []
	var unopened_gifts := get_unopened_pending_gifts()

	if unopened_gifts.is_empty():
		lines.append("当前没有未查看的特殊客人回响。")
		return lines

	lines.append("特殊客人的回响：")

	for gift_data in unopened_gifts:
		var display_name := str(gift_data.get("display_name", ""))

		if display_name == "":
			var source_name := str(gift_data.get("source_name", "特殊客人"))
			var result := str(gift_data.get("result", "neutral"))

			if result == "good":
				display_name = "%s留下的祝愿" % source_name
			elif result == "bad":
				display_name = "%s留下的呸" % source_name
			else:
				display_name = "%s留下的回响" % source_name

		lines.append(" - %s" % display_name)

	return lines


func record_today_served_customer() -> void:
	today_customers_served += 1


func record_today_failed_customer() -> void:
	today_customers_failed += 1


func record_today_special_echo(display_name: String, result: String) -> void:
	today_special_echo_records.append({
		"display_name": display_name,
		"result": result
	})


func get_today_stall_echo_lines() -> Array[String]:
	var lines: Array[String] = []

	lines.append("今日小摊回响：")
	lines.append("服务顾客：%d" % today_customers_served)
	lines.append("满意离开：%d" % today_customers_served)
	lines.append("遗憾离开：%d" % today_customers_failed)

	if today_special_echo_records.is_empty():
		lines.append("特殊客人回响：无")
	else:
		var echo_names: Array[String] = []

		for record in today_special_echo_records:
			if typeof(record) != TYPE_DICTIONARY:
				continue

			echo_names.append(str(record.get("display_name", "特殊客人的回响")))

		if echo_names.is_empty():
			lines.append("特殊客人回响：无")
		else:
			lines.append("特殊客人回响：%s" % "，".join(echo_names))

	return lines


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	if typeof(pending_gifts) != TYPE_ARRAY:
		warnings.append("RunEchoState: pending_gifts is not an Array.")

	if typeof(opened_gifts) != TYPE_ARRAY:
		warnings.append("RunEchoState: opened_gifts is not an Array.")

	if gift_sequence_id < 0:
		warnings.append("RunEchoState: gift_sequence_id is negative.")

	return warnings
