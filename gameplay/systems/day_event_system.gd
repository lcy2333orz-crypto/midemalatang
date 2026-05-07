class_name DayEventSystem
extends RefCounted

const DayGiftPanelControllerScript = preload("res://scenes/ui/day_gift_panel_controller.gd")
const MorningInfoPanelControllerScript = preload("res://scenes/ui/morning_info_panel_controller.gd")

var manager = null
var day_gift_panel_controller: DayGiftPanelController = null
var morning_info_panel_controller: MorningInfoPanelController = null

var morning_info_layer: CanvasLayer = null
var day_gift_layer: CanvasLayer = null
var day_gift_current_gift_id: String = ""
var day_gift_current_options: Array = []


func bind(game_manager: Node) -> void:
	manager = game_manager

	day_gift_panel_controller = DayGiftPanelControllerScript.new()
	day_gift_panel_controller.bind(manager, self)

	morning_info_panel_controller = MorningInfoPanelControllerScript.new()
	morning_info_panel_controller.bind(manager)


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	if manager == null or not is_instance_valid(manager):
		warnings.append("DayEventSystem is not bound to a valid GameManager.")
		return warnings

	if day_gift_panel_controller == null:
		warnings.append("DayEventSystem: DayGiftPanelController is missing.")

	if morning_info_panel_controller == null:
		warnings.append("DayEventSystem: MorningInfoPanelController is missing.")

	return warnings


func interact_with_gift_box() -> void:
	if day_gift_panel_controller != null and day_gift_panel_controller.is_open():
		print("ç¤¼ç‰©é€‰æ‹©é¢æ¿å·²ç»æ‰“å¼€ã€‚")
		return

	var unopened_gifts: Array = RunSetupData.get_unopened_pending_gifts()

	if unopened_gifts.is_empty():
		print("ç¤¼ç‰©ç›’æ˜¯ç©ºçš„ã€‚å½“å‰æ²¡æœ‰æœªæ‰“å¼€çš„ç‰¹æ®Šå®¢äººç¤¼ç‰©ã€‚")
		return

	var gift_data: Dictionary = unopened_gifts[0]
	open_day_gift_choice_panel(gift_data)


func open_day_gift_choice_panel(gift_data: Dictionary) -> void:
	if gift_data.is_empty():
		print("ä¸èƒ½æ‰“å¼€ç©ºç¤¼ç‰©ã€‚")
		return

	var gift_id: String = str(gift_data.get("gift_id", ""))
	if gift_id == "":
		print("ç¤¼ç‰©æ²¡æœ‰ gift_idï¼Œä¸èƒ½æ‰“å¼€ã€‚")
		return

	day_gift_current_gift_id = gift_id

	var saved_options: Array = RunSetupData.get_gift_current_options(gift_id)
	if saved_options.is_empty():
		day_gift_current_options = generate_day_gift_options(gift_data)
		RunSetupData.set_gift_current_options(gift_id, day_gift_current_options)
	else:
		day_gift_current_options = saved_options

	day_gift_panel_controller.open(gift_data, day_gift_current_options)
	day_gift_layer = day_gift_panel_controller.layer

	print("æ‰“å¼€ç™½å¤©ç¤¼ç‰©ï¼š", gift_data)
	print("ç™½å¤©ç¤¼ç‰©é€‰é¡¹ï¼š", day_gift_current_options)


func close_day_gift_choice_panel() -> void:
	if day_gift_panel_controller != null:
		day_gift_panel_controller.close()

	day_gift_layer = null
	day_gift_current_gift_id = ""
	day_gift_current_options.clear()


func generate_day_gift_options(gift_data: Dictionary) -> Array:
	var result: String = str(gift_data.get("result", "neutral"))
	var source_type: String = str(gift_data.get("source_type", ""))

	if result == "bad":
		return [
			_build_day_gift_option("mouse_bad_slow_start", "UI_GIFT_MOUSE_BAD_SLOW_START_NAME", "UI_GIFT_MOUSE_BAD_SLOW_START_DESC", "active_effect"),
			_build_day_gift_option("mouse_bad_extra_cost", "UI_GIFT_MOUSE_BAD_EXTRA_COST_NAME", "UI_GIFT_MOUSE_BAD_EXTRA_COST_DESC", "instant_money", {"money_delta": -2}),
			_build_day_gift_option("mouse_bad_reputation", "UI_GIFT_MOUSE_BAD_REPUTATION_NAME", "UI_GIFT_MOUSE_BAD_REPUTATION_DESC", "instant_reputation", {"reputation_delta": -1})
		]

	if source_type == "mouse":
		return [
			_build_day_gift_option("busy_stall", "UI_GIFT_BUSY_STALL_NAME", "UI_GIFT_BUSY_STALL_DESC", "active_effect"),
			_build_day_gift_option("mouse_spare_coin", "UI_GIFT_MOUSE_SPARE_COIN_NAME", "UI_GIFT_MOUSE_SPARE_COIN_DESC", "instant_money", {"money_delta": 2}),
			_build_day_gift_option("mouse_found_spinach", "UI_GIFT_MOUSE_FOUND_SPINACH_NAME", "UI_GIFT_MOUSE_FOUND_SPINACH_DESC", "instant_stock", {"stock_item_id": "spinach", "stock_amount": 2})
		]

	return [
		_build_day_gift_option("small_tip", "UI_GIFT_SMALL_TIP_NAME", "UI_GIFT_SMALL_TIP_DESC", "instant_money", {"money_delta": 1}),
		_build_day_gift_option("warm_memory", "UI_GIFT_WARM_MEMORY_NAME", "UI_GIFT_WARM_MEMORY_DESC", "instant_reputation", {"reputation_delta": 1}),
		_build_day_gift_option("steady_paws", "UI_GIFT_STEADY_PAWS_NAME", "UI_GIFT_STEADY_PAWS_DESC", "active_effect")
	]


func _build_day_gift_option(option_id: String, name_key: String, description_key: String, effect_type: String, extra_data: Dictionary = {}) -> Dictionary:
	var option_data: Dictionary = {
		"id": option_id,
		"name": TextDB.get_text(name_key),
		"description": TextDB.get_text(description_key),
		"effect_type": effect_type
	}

	for key in extra_data.keys():
		option_data[key] = extra_data[key]

	return option_data

func _on_day_gift_option_pressed(option_index: int) -> void:
	if day_gift_current_gift_id == "":
		print("æ²¡æœ‰æ­£åœ¨æ‰“å¼€çš„ç¤¼ç‰©ã€‚")
		return

	if option_index < 0 or option_index >= day_gift_current_options.size():
		print("ç¤¼ç‰©é€‰é¡¹ç¼–å·æ— æ•ˆï¼š", option_index)
		return

	var chosen_card: Dictionary = day_gift_current_options[option_index]
	var gift_data: Dictionary = RunSetupData.get_unopened_gift_by_id(day_gift_current_gift_id)

	if gift_data.is_empty():
		print("è¿™ä¸ªç¤¼ç‰©å·²ç»è¢«æ‰“å¼€ï¼Œæˆ–è€…æ‰¾ä¸åˆ°ã€‚")
		close_day_gift_choice_panel()
		return

	apply_day_gift_choice(gift_data, chosen_card)
	RunSetupData.mark_gift_opened(day_gift_current_gift_id, chosen_card)

	print("ç™½å¤©æ‰“å¼€ç¤¼ç‰©ï¼Œé€‰æ‹©ï¼š", chosen_card)

	close_day_gift_choice_panel()


func apply_day_gift_choice(gift_data: Dictionary, chosen_card: Dictionary) -> void:
	var effect_type: String = str(chosen_card.get("effect_type", "active_effect"))
	var card_id: String = str(chosen_card.get("id", "unknown_card"))
	var card_name: String = str(chosen_card.get("name", TextDB.get_text("UI_FALLBACK_UNKNOWN_CARD")))
	var gift_id: String = str(gift_data.get("gift_id", ""))
	var display_name: String = str(gift_data.get("display_name", TextDB.get_text("UI_DAY_GIFT_DEFAULT_TITLE")))
	var result: String = str(gift_data.get("result", "neutral"))

	if effect_type == "instant_money":
		var money_delta: int = int(chosen_card.get("money_delta", 0))

		if money_delta >= 0:
			manager.add_money(money_delta)
		else:
			var cost: int = abs(money_delta)
			if not manager.spend_money(cost):
				print("å³æ—¶é‡‘é’±æƒ©ç½šæ— æ³•å®Œå…¨æ”¯ä»˜ã€‚éœ€è¦ï¼š", cost, " å½“å‰ï¼š", manager.money)

	elif effect_type == "instant_reputation":
		var reputation_delta: int = int(chosen_card.get("reputation_delta", 0))
		if reputation_delta != 0:
			manager.change_reputation(reputation_delta, "day gift")

	elif effect_type == "instant_stock":
		var item_id: String = str(chosen_card.get("stock_item_id", ""))
		var amount: int = int(chosen_card.get("stock_amount", 0))

		if item_id != "" and amount > 0:
			manager.inventory_system.add_stock(item_id, amount)

			print("ç¤¼ç‰©èŽ·å¾—åº“å­˜ï¼š", manager.get_ingredient_display_name(item_id), " x", amount)

	else:
		RunSetupData.active_effects.append({
			"source": display_name,
			"type": "special_echo",
			"result": result,
			"effect_id": card_id,
			"effect": card_name,
			"from_gift_id": gift_id
		})

	print("å½“å‰å·²èŽ·å¾—æ•ˆæžœåˆ—è¡¨ï¼š", RunSetupData.active_effects)


func get_day_gift_option_button_text(option_data: Dictionary) -> String:
	var name: String = str(option_data.get("name", TextDB.get_text("UI_FALLBACK_UNKNOWN_CARD")))
	var desc: String = str(option_data.get("description", ""))
	return "%s\n\n%s" % [name, desc]


func activate_and_apply_current_day_business_event() -> void:
	var event: Dictionary = RunSetupData.activate_pending_tomorrow_event()

	if event.is_empty():
		return

	print("Activated tomorrow business event: ", event)

	var raw_bonus: int = int(RunSetupData.get_current_day_additive("random_raw_stock_bonus", 0.0))

	if raw_bonus > 0:
		apply_random_raw_stock_bonus(raw_bonus)


func apply_random_raw_stock_bonus(amount: int) -> void:
	if amount <= 0:
		return

	var item_pool: Array[String] = RunSetupData.get_basic_ingredient_ids()

	if item_pool.is_empty():
		return

	var gained: Dictionary = {}

	for i in range(amount):
		var item_id: String = item_pool[randi() % item_pool.size()]

		manager.inventory_system.add_stock(item_id, 1)
		gained[item_id] = int(gained.get(item_id, 0)) + 1

	print("Morning raw stock bonus applied: ", gained)
	print("Raw stock after morning bonus: ", manager.raw_stock)


func show_pending_morning_info_if_any() -> void:
	var lines: Array[String] = RunSetupData.consume_pending_morning_info_lines()

	if lines.is_empty():
		return

	print("=== æ˜¨æ™šå°çŒ«èŽ·å¾—çš„ä¿¡æ¯ ===")

	for line in lines:
		print(line)

	_create_morning_info_layer(lines)


func _create_morning_info_layer(lines: Array[String]) -> void:
	if morning_info_panel_controller == null:
		return

	morning_info_panel_controller.show(lines)
	morning_info_layer = morning_info_panel_controller.layer
