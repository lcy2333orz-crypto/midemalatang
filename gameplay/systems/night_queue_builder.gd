class_name NightQueueBuilder
extends RefCounted

var manager = null


func bind(game_manager: Node) -> void:
	manager = game_manager


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	if manager == null or not is_instance_valid(manager):
		warnings.append("NightQueueBuilder is not bound to a valid GameManager.")

	return warnings


func build_from_today_results() -> Array:
	var queue: Array = [
		{
			"type": "insight",
			"name": TextDB.get_text("UI_NIGHT_CHOICE_INSIGHT"),
			"result": "neutral"
		}
	]

	for entry in RunSetupData.today_special_customer_results:
		var gift_id: String = str(entry.get("gift_id", ""))

		if gift_id != "" and RunSetupData.is_gift_opened(gift_id):
			print("Skip opened special echo at night: ", gift_id)
			continue

		var result_text: String = str(entry.get("result", "neutral"))
		var entry_name: String = str(entry.get("name", TextDB.get_text("UI_FALLBACK_SPECIAL_CUSTOMER")))

		if result_text == "good":
			queue.append({
				"type": "good",
				"name": entry_name,
				"result": "good",
				"gift_id": gift_id
			})
		elif result_text == "bad":
			queue.append({
				"type": "bad",
				"name": entry_name,
				"result": "bad",
				"gift_id": gift_id
			})

	return queue
