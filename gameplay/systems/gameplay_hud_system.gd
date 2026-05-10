class_name GameplayHudSystem
extends RefCounted

const CustomerOrderState = preload("res://gameplay/models/customer_order_state.gd")

var manager = null
var tutorial_has_seen_storage: bool = false
var tutorial_stage: String = "off"
var tutorial_checkout_count: int = 0
var tutorial_delivered_count: int = 0
var special_tutorial_echo_left: bool = false
var special_tutorial_echo_checked: bool = false

const TUTORIAL_STAGE_OFF = "off"
const TUTORIAL_STAGE_CHECK_STORAGE = "check_storage"
const TUTORIAL_STAGE_OPEN_BUSINESS = "open_business"
const TUTORIAL_STAGE_VIEW_ORDER = "view_order"
const TUTORIAL_STAGE_TAKE_PAYMENT = "take_payment"
const TUTORIAL_STAGE_COOK_FIRST_ORDER_POT = "cook_first_order_pot"
const TUTORIAL_STAGE_COOK_FIRST_ORDER_STAPLE = "cook_first_order_staple"
const TUTORIAL_STAGE_TAKE_FIRST_STAPLE = "take_first_staple"
const TUTORIAL_STAGE_DELIVER_FIRST_ORDER = "deliver_first_order"
const TUTORIAL_STAGE_SECOND_CUSTOMER = "second_customer"
const TUTORIAL_STAGE_COOK_SECOND_ORDER_POT = "cook_second_order_pot"
const TUTORIAL_STAGE_COOK_SECOND_ORDER_STAPLE = "cook_second_order_staple"
const TUTORIAL_STAGE_TAKE_SECOND_STAPLE = "take_second_staple"
const TUTORIAL_STAGE_DELIVER_SECOND_ORDER = "deliver_second_order"
const TUTORIAL_STAGE_TIMER_STARTED = "timer_started"
const TUTORIAL_STAGE_FREE_PLAY = "free_play"
const TUTORIAL_STAGE_AUTO_CLOSED_CLEANUP = "auto_closed_cleanup"
const TUTORIAL_STAGE_DAY_SETTLEMENT = "day_settlement"

func bind(game_manager: Node) -> void:
	manager = game_manager


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	if manager == null or not is_instance_valid(manager):
		warnings.append("GameplayHudSystem is not bound to a valid GameManager.")

	return warnings


func update() -> void:
	var game_ui = manager.get_tree().get_first_node_in_group("game_ui")
	if game_ui == null:
		return

	advance_tutorial_stage_from_state()

	game_ui.update_business_state(
		manager.day_time_left,
		manager.is_open_for_business,
		manager.is_round_closing,
		manager.has_round_finished,
		manager.is_cleanup_phase
	)

	game_ui.hide_patience()
	_refresh_pending_order_cards(game_ui)
	_refresh_tutorial_hint(game_ui)


func reset_for_new_day() -> void:
	reset_tutorial_state_for_new_day()

	var game_ui = manager.get_tree().get_first_node_in_group("game_ui")
	if game_ui == null:
		return

	game_ui.update_money(manager.economy_system.money)
	game_ui.hide_order()
	game_ui.hide_stock()
	game_ui.hide_patience()
	game_ui.hide_pending_orders()
	game_ui.update_business_state(
		manager.day_time_left,
		manager.is_open_for_business,
		manager.is_round_closing,
		manager.has_round_finished,
		manager.is_cleanup_phase
	)


func reset_tutorial_state_for_new_day() -> void:
	tutorial_has_seen_storage = false
	tutorial_checkout_count = 0
	tutorial_delivered_count = 0
	special_tutorial_echo_left = false
	special_tutorial_echo_checked = false

	if RunSetupData.is_tutorial_day():
		tutorial_stage = TUTORIAL_STAGE_CHECK_STORAGE
	else:
		tutorial_stage = TUTORIAL_STAGE_OFF


func notify_order_revealed(_customer: Node) -> void:
	if not RunSetupData.is_tutorial_day():
		return

	advance_tutorial_stage(TUTORIAL_STAGE_TAKE_PAYMENT)


func notify_checkout_completed(_customer: Node) -> void:
	if not RunSetupData.is_tutorial_day():
		return

	tutorial_checkout_count += 1

	if tutorial_checkout_count == 1:
		advance_tutorial_stage(TUTORIAL_STAGE_COOK_FIRST_ORDER_POT)
	elif tutorial_checkout_count == 2 and tutorial_delivered_count < 2:
		advance_tutorial_stage(TUTORIAL_STAGE_SECOND_CUSTOMER)


func notify_order_delivered(_customer: Node) -> void:
	if not RunSetupData.is_tutorial_day():
		return

	tutorial_delivered_count += 1

	if tutorial_delivered_count == 1:
		advance_tutorial_stage(TUTORIAL_STAGE_SECOND_CUSTOMER)
	elif tutorial_delivered_count >= 2:
		advance_tutorial_stage(TUTORIAL_STAGE_TIMER_STARTED)


func notify_order_ready_for_delivery(_customer: Node) -> void:
	if not RunSetupData.is_tutorial_day():
		return

	if tutorial_delivered_count == 0:
		advance_tutorial_stage(TUTORIAL_STAGE_DELIVER_FIRST_ORDER)
	elif tutorial_delivered_count == 1:
		advance_tutorial_stage(TUTORIAL_STAGE_DELIVER_SECOND_ORDER)


func notify_auto_closed_by_timer() -> void:
	if not RunSetupData.is_tutorial_day():
		return

	advance_tutorial_stage(TUTORIAL_STAGE_AUTO_CLOSED_CLEANUP)


func notify_tutorial_emergency_purchase_completed(_customer: Node) -> void:
	if not RunSetupData.is_tutorial_day():
		return

	if tutorial_checkout_count >= 2 and tutorial_delivered_count == 1:
		advance_tutorial_stage(TUTORIAL_STAGE_COOK_SECOND_ORDER_POT)


func notify_special_customer_tutorial_echo_left(_gift_data: Dictionary) -> void:
	if not RunSetupData.is_special_customer_tutorial_day():
		return

	special_tutorial_echo_left = true
	special_tutorial_echo_checked = false


func notify_special_customer_tutorial_echo_checked(_gift_id: String = "") -> void:
	if not RunSetupData.is_special_customer_tutorial_day():
		return

	special_tutorial_echo_checked = true


func is_tutorial_timer_paused() -> bool:
	return RunSetupData.is_tutorial_day() and tutorial_delivered_count < 2


func advance_tutorial_stage_from_state() -> void:
	if not RunSetupData.is_tutorial_day():
		tutorial_stage = TUTORIAL_STAGE_OFF
		return

	if tutorial_stage == TUTORIAL_STAGE_OFF:
		tutorial_stage = TUTORIAL_STAGE_CHECK_STORAGE

	if tutorial_stage == TUTORIAL_STAGE_OPEN_BUSINESS and manager.has_opened_for_business_today:
		advance_tutorial_stage(TUTORIAL_STAGE_VIEW_ORDER)

	if tutorial_stage == TUTORIAL_STAGE_COOK_FIRST_ORDER_POT:
		var first_customer_for_pot: Node = get_first_tutorial_pending_customer()
		if first_customer_for_pot != null and is_instance_valid(first_customer_for_pot):
			if not CustomerOrderState.needs_ingredients(first_customer_for_pot) \
			or has_started_cart_pot_batch_for_customer(first_customer_for_pot):
				advance_tutorial_stage(TUTORIAL_STAGE_COOK_FIRST_ORDER_STAPLE)

	if tutorial_stage == TUTORIAL_STAGE_COOK_FIRST_ORDER_STAPLE:
		if is_first_tutorial_staple_ready_in_ladle():
			advance_tutorial_stage(TUTORIAL_STAGE_TAKE_FIRST_STAPLE)

	if tutorial_stage == TUTORIAL_STAGE_TAKE_FIRST_STAPLE:
		if manager.cooking_system.held_staple_food_id == "glass_noodle":
			advance_tutorial_stage(TUTORIAL_STAGE_DELIVER_FIRST_ORDER)

	if tutorial_stage == TUTORIAL_STAGE_COOK_SECOND_ORDER_POT:
		var second_customer_for_pot: Node = get_first_tutorial_pending_customer()
		if second_customer_for_pot != null and is_instance_valid(second_customer_for_pot):
			if not CustomerOrderState.needs_ingredients(second_customer_for_pot) \
			or has_started_cart_pot_batch_for_customer(second_customer_for_pot):
				advance_tutorial_stage(TUTORIAL_STAGE_COOK_SECOND_ORDER_STAPLE)

	if tutorial_stage == TUTORIAL_STAGE_COOK_SECOND_ORDER_STAPLE:
		if is_tutorial_staple_ready_in_ladle("noodle"):
			advance_tutorial_stage(TUTORIAL_STAGE_TAKE_SECOND_STAPLE)

	if tutorial_stage == TUTORIAL_STAGE_TAKE_SECOND_STAPLE:
		if manager.cooking_system.held_staple_food_id == "noodle":
			advance_tutorial_stage(TUTORIAL_STAGE_DELIVER_SECOND_ORDER)

	if tutorial_stage == TUTORIAL_STAGE_COOK_FIRST_ORDER_POT \
	or tutorial_stage == TUTORIAL_STAGE_COOK_FIRST_ORDER_STAPLE \
	or tutorial_stage == TUTORIAL_STAGE_TAKE_FIRST_STAPLE \
	or tutorial_stage == TUTORIAL_STAGE_COOK_SECOND_ORDER_POT \
	or tutorial_stage == TUTORIAL_STAGE_COOK_SECOND_ORDER_STAPLE \
	or tutorial_stage == TUTORIAL_STAGE_TAKE_SECOND_STAPLE:
		var ready_customer: Node = manager.pending_order_system.get_first_deliverable()
		if ready_customer != null and is_instance_valid(ready_customer):
			notify_order_ready_for_delivery(ready_customer)

	if manager.is_cleanup_phase:
		advance_tutorial_stage(TUTORIAL_STAGE_DAY_SETTLEMENT)


func get_first_tutorial_pending_customer() -> Node:
	for customer in manager.pending_order_system.get_all():
		if customer == null or not is_instance_valid(customer):
			continue

		if CustomerOrderState.is_served(customer):
			continue

		return customer

	return null


func has_started_cart_pot_batch_for_customer(customer: Node) -> bool:
	if customer == null or not is_instance_valid(customer):
		return false

	var needed_ingredients: Dictionary = manager.cooking_system.get_cart_ingredients_needed_from_pot(customer)
	if needed_ingredients.is_empty():
		return true

	var cooking_amounts: Dictionary = {}

	for batch_data in manager.cooking_system.cart_pot_cooking_batches:
		if typeof(batch_data) != TYPE_DICTIONARY:
			continue

		var batch: Dictionary = batch_data as Dictionary
		var batch_items = batch.get("items", {})
		if typeof(batch_items) != TYPE_DICTIONARY:
			continue

		for item_id in needed_ingredients.keys():
			var item_key: String = str(item_id)
			cooking_amounts[item_key] = int(cooking_amounts.get(item_key, 0)) + int(batch_items.get(item_key, 0))

	for item_id in needed_ingredients.keys():
		var item_key: String = str(item_id)
		if int(cooking_amounts.get(item_key, 0)) < int(needed_ingredients.get(item_key, 0)):
			return false

	return true


func is_first_tutorial_staple_ready_in_ladle() -> bool:
	return is_tutorial_staple_ready_in_ladle("glass_noodle")


func is_tutorial_staple_ready_in_ladle(main_food_id: String) -> bool:
	for slot_data in manager.cooking_system.staple_ladle_slots:
		if typeof(slot_data) != TYPE_DICTIONARY:
			continue

		var slot: Dictionary = slot_data as Dictionary
		if str(slot.get("state", "")) == "ready" and str(slot.get("main_food_id", "")) == main_food_id:
			return true

	return false


func advance_tutorial_stage(next_stage: String) -> void:
	if _get_tutorial_stage_index(next_stage) > _get_tutorial_stage_index(tutorial_stage):
		tutorial_stage = next_stage


func _get_tutorial_stage_index(stage: String) -> int:
	match stage:
		TUTORIAL_STAGE_OFF:
			return 0
		TUTORIAL_STAGE_CHECK_STORAGE:
			return 1
		TUTORIAL_STAGE_OPEN_BUSINESS:
			return 2
		TUTORIAL_STAGE_VIEW_ORDER:
			return 3
		TUTORIAL_STAGE_TAKE_PAYMENT:
			return 4
		TUTORIAL_STAGE_COOK_FIRST_ORDER_POT:
			return 5
		TUTORIAL_STAGE_COOK_FIRST_ORDER_STAPLE:
			return 6
		TUTORIAL_STAGE_TAKE_FIRST_STAPLE:
			return 7
		TUTORIAL_STAGE_DELIVER_FIRST_ORDER:
			return 8
		TUTORIAL_STAGE_SECOND_CUSTOMER:
			return 9
		TUTORIAL_STAGE_COOK_SECOND_ORDER_POT:
			return 10
		TUTORIAL_STAGE_COOK_SECOND_ORDER_STAPLE:
			return 11
		TUTORIAL_STAGE_TAKE_SECOND_STAPLE:
			return 12
		TUTORIAL_STAGE_DELIVER_SECOND_ORDER:
			return 13
		TUTORIAL_STAGE_TIMER_STARTED:
			return 14
		TUTORIAL_STAGE_FREE_PLAY:
			return 15
		TUTORIAL_STAGE_AUTO_CLOSED_CLEANUP:
			return 16
		TUTORIAL_STAGE_DAY_SETTLEMENT:
			return 17
		_:
			return 0


func refresh_money_and_reputation_ui() -> void:
	var game_ui = manager.get_tree().get_first_node_in_group("game_ui")
	if game_ui:
		game_ui.update_money(manager.economy_system.money)


func show_storage_stock_only() -> void:
	var game_ui = manager.get_tree().get_first_node_in_group("game_ui")

	if game_ui == null:
		print("Cannot show storage stock. No game_ui found.")
		return

	var cooked_text: String = manager.inventory_system.get_cooked_stock_text()
	var raw_and_staple_text: String = "%s
%s" % [
		manager.inventory_system.get_raw_stock_text(),
		TextDB.get_text("UI_STAPLE_STOCK_LINE") % manager.inventory_system.get_staple_stock_text()
	]

	game_ui.show_stock(cooked_text, raw_and_staple_text)

	print("Show storage stock only.")
	print("Cooked stock text: ", cooked_text)
	print("Raw / staple stock text: ", raw_and_staple_text)

	if RunSetupData.is_tutorial_day():
		tutorial_has_seen_storage = true
		if tutorial_stage == TUTORIAL_STAGE_CHECK_STORAGE:
			advance_tutorial_stage(TUTORIAL_STAGE_OPEN_BUSINESS)


func hide_order_and_pending() -> void:
	var game_ui = manager.get_tree().get_first_node_in_group("game_ui")
	if game_ui:
		game_ui.hide_order()
		game_ui.hide_patience()
		game_ui.hide_pending_orders()


func _refresh_pending_order_cards(game_ui: Node) -> void:
	var order_cards: Array = []

	for customer in manager.pending_order_system.get_all():
		if customer != null and is_instance_valid(customer):
			if not CustomerOrderState.is_served(customer):
				order_cards.append(manager.order_system.get_pending_order_card_data(customer))

	if order_cards.is_empty():
		game_ui.hide_pending_orders()
	else:
		game_ui.show_pending_orders(order_cards)


func _refresh_tutorial_hint(game_ui: Node) -> void:
	var hint_text: String = _get_tutorial_hint_text()

	if hint_text == "":
		if game_ui.has_method("hide_tutorial_hint"):
			game_ui.hide_tutorial_hint()
		return

	if game_ui.has_method("show_tutorial_hint"):
		game_ui.show_tutorial_hint(hint_text)


func _get_tutorial_hint_text() -> String:
	if RunSetupData.is_tutorial_day():
		return _get_first_day_tutorial_hint_text()

	if RunSetupData.is_special_customer_tutorial_day():
		return _get_special_customer_tutorial_hint_text()

	return ""


func _get_first_day_tutorial_hint_text() -> String:
	if manager.has_round_finished:
		return ""

	if manager.is_cleanup_phase:
		return TextDB.get_text("UI_TUTORIAL_CLEANUP")

	if manager.is_round_closing:
		if tutorial_stage == TUTORIAL_STAGE_AUTO_CLOSED_CLEANUP:
			return TextDB.get_text("UI_TUTORIAL_AUTO_CLOSED_CLEANUP")

		return TextDB.get_text("UI_TUTORIAL_WAIT_CLEANUP")

	if not manager.has_opened_for_business_today:
		if tutorial_stage == TUTORIAL_STAGE_CHECK_STORAGE or not tutorial_has_seen_storage:
			return TextDB.get_text("UI_TUTORIAL_CHECK_STORAGE")

		return get_tutorial_pre_open_supply_hint()

	if not manager.is_open_for_business:
		return ""

	if tutorial_stage == TUTORIAL_STAGE_COOK_FIRST_ORDER_POT:
		return TextDB.get_text("UI_TUTORIAL_FIRST_ORDER_BIG_POT")

	if tutorial_stage == TUTORIAL_STAGE_COOK_FIRST_ORDER_STAPLE:
		return TextDB.get_text("UI_TUTORIAL_FIRST_ORDER_STAPLE")

	if tutorial_stage == TUTORIAL_STAGE_TAKE_FIRST_STAPLE:
		return TextDB.get_text("UI_TUTORIAL_TAKE_FIRST_STAPLE")

	if tutorial_stage == TUTORIAL_STAGE_DELIVER_FIRST_ORDER:
		return TextDB.get_text("UI_TUTORIAL_READY_TO_DELIVER")

	if tutorial_stage == TUTORIAL_STAGE_SECOND_CUSTOMER:
		return TextDB.get_text("UI_TUTORIAL_SECOND_CUSTOMER_NOODLE")

	if tutorial_stage == TUTORIAL_STAGE_COOK_SECOND_ORDER_POT:
		return TextDB.get_text("UI_TUTORIAL_SECOND_ORDER_BIG_POT")

	if tutorial_stage == TUTORIAL_STAGE_COOK_SECOND_ORDER_STAPLE:
		return TextDB.get_text("UI_TUTORIAL_SECOND_ORDER_STAPLE")

	if tutorial_stage == TUTORIAL_STAGE_TAKE_SECOND_STAPLE:
		return TextDB.get_text("UI_TUTORIAL_TAKE_SECOND_STAPLE")

	if tutorial_stage == TUTORIAL_STAGE_DELIVER_SECOND_ORDER:
		return TextDB.get_text("UI_TUTORIAL_SECOND_READY_TO_DELIVER")

	if tutorial_stage == TUTORIAL_STAGE_TIMER_STARTED:
		return TextDB.get_text("UI_TUTORIAL_TIMER_STARTED")

	if tutorial_stage == TUTORIAL_STAGE_FREE_PLAY:
		return TextDB.get_text("UI_TUTORIAL_FREE_PLAY")

	var counter_customer = manager.customer_queue_system.get_counter_customer()
	if tutorial_stage == TUTORIAL_STAGE_VIEW_ORDER and counter_customer != null and is_instance_valid(counter_customer):
		if not bool(counter_customer.order_revealed):
			return TextDB.get_text("UI_TUTORIAL_VIEW_ORDER")

	if tutorial_stage == TUTORIAL_STAGE_TAKE_PAYMENT and counter_customer != null and is_instance_valid(counter_customer):
		if bool(counter_customer.order_revealed) and not bool(counter_customer.is_checked_out):
			return TextDB.get_text("UI_TUTORIAL_TAKE_PAYMENT")

	if manager.pending_order_system.has_pending():
		if manager.pending_order_system.get_first_deliverable() != null:
			return TextDB.get_text("UI_TUTORIAL_READY_TO_DELIVER")

		if manager.cooking_system.held_staple_food_id != "":
			return TextDB.get_text("UI_TUTORIAL_DELIVER_STAPLE")

		if manager.cooking_system.held_raw_staple_food_id != "":
			return TextDB.get_text("UI_TUTORIAL_PUT_STAPLE_IN_LADLE")

		if manager.cooking_system.has_busy_cooking():
			return TextDB.get_text("UI_TUTORIAL_WAIT_COOKING")

		return TextDB.get_text("UI_TUTORIAL_PREPARE_ORDER")

	return TextDB.get_text("UI_TUTORIAL_WAIT_CUSTOMER")


func get_tutorial_pre_open_supply_hint() -> String:
	if manager.supplier_system == null:
		return TextDB.get_text("UI_TUTORIAL_OPEN_BUSINESS")

	if manager.supplier_system.are_tutorial_required_supplies_delivered():
		return TextDB.get_text("UI_TUTORIAL_SUPPLIES_DELIVERED_OPEN")

	if manager.supplier_system.are_tutorial_required_supplies_ordered():
		return TextDB.get_text("UI_TUTORIAL_SUPPLIES_ORDERED_WAIT_OR_OPEN")

	var missing_names: Array[String] = manager.supplier_system.get_tutorial_missing_supply_names(false)
	return TextDB.get_text("UI_TUTORIAL_BUY_SUPPLIES") % ", ".join(missing_names)


func _get_special_customer_tutorial_hint_text() -> String:
	if manager.has_round_finished:
		return ""

	if manager.is_cleanup_phase:
		return ""

	if special_tutorial_echo_left:
		if special_tutorial_echo_checked:
			return ""

		if RunSetupData.has_unopened_pending_gifts():
			return TextDB.get_text("UI_TUTORIAL_SPECIAL_CUSTOMER_ECHO")

		special_tutorial_echo_checked = true
		return ""

	if manager.has_opened_for_business_today and manager.is_open_for_business:
		return TextDB.get_text("UI_TUTORIAL_SPECIAL_CUSTOMER_CARE")

	return ""
