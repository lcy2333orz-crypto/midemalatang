class_name CookingSystem
extends RefCounted

const CustomerOrderState := preload("res://gameplay/models/customer_order_state.gd")
const CartPotPanelControllerScript := preload("res://scenes/ui/cart_pot_panel_controller.gd")

var manager = null
var panel_controller: CartPotPanelController = null

var cart_pot_capacity: int = 6
var cart_pot_batch_duration: float = 3.0
var cart_pot_is_cooking: bool = false
var cart_pot_time_left: float = 0.0
var cart_pot_cooking_batch: Dictionary = {}
var cart_pot_selection: Dictionary = {}

var staple_ladle_duration: float = 3.0
var staple_ladle_slots: Array = []
var held_raw_staple_food_id: String = ""
var held_staple_food_id: String = ""


func bind(game_manager: Node) -> void:
	manager = game_manager
	panel_controller = CartPotPanelControllerScript.new()
	panel_controller.bind(manager, self)


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	if manager == null or not is_instance_valid(manager):
		warnings.append("CookingSystem is not bound to a valid GameManager.")
		return warnings

	if typeof(staple_ladle_slots) != TYPE_ARRAY:
		warnings.append("CookingSystem: staple_ladle_slots is not an Array.")

	if typeof(cart_pot_selection) != TYPE_DICTIONARY:
		warnings.append("CookingSystem: cart_pot_selection is not a Dictionary.")

	if typeof(cart_pot_cooking_batch) != TYPE_DICTIONARY:
		warnings.append("CookingSystem: cart_pot_cooking_batch is not a Dictionary.")

	if cart_pot_time_left < 0.0:
		warnings.append("CookingSystem: cart_pot_time_left is negative.")

	return warnings


func update(delta: float) -> void:
	manager.update_cooker_slots(delta)
	update_cart_pot(delta)
	update_staple_ladle_slots(delta)


func open_cart_pot_panel() -> void:
	panel_controller.open()


func _build_ladle_row(ladle_index: int) -> HBoxContainer:
	var slot_index: int = ladle_index - 1

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var state_label := Label.new()
	state_label.custom_minimum_size = Vector2(190, 28)
	state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state_label.text = _get_ladle_state_text(ladle_index)
	row.add_child(state_label)

	var slot_state: String = "empty"

	if slot_index >= 0 and slot_index < staple_ladle_slots.size():
		var slot: Dictionary = staple_ladle_slots[slot_index] as Dictionary
		slot_state = str(slot.get("state", "empty"))

	var cook_glass_button := Button.new()
	cook_glass_button.text = "ç…®ç²‰ä¸"
	cook_glass_button.custom_minimum_size = Vector2(74, 28)
	cook_glass_button.disabled = not can_start_staple_ladle_cooking(slot_index, "glass_noodle")
	row.add_child(cook_glass_button)

	var cook_noodle_button := Button.new()
	cook_noodle_button.text = "ç…®é¢"
	cook_noodle_button.custom_minimum_size = Vector2(74, 28)
	cook_noodle_button.disabled = not can_start_staple_ladle_cooking(slot_index, "noodle")
	row.add_child(cook_noodle_button)

	var take_out_button := Button.new()
	take_out_button.text = "å–å‡º"
	take_out_button.custom_minimum_size = Vector2(64, 28)
	take_out_button.disabled = slot_state != "ready" or held_staple_food_id != ""
	row.add_child(take_out_button)

	return row


func _get_ladle_state_text(ladle_index: int) -> String:
	var slot_index := ladle_index - 1

	if slot_index < 0 or slot_index >= staple_ladle_slots.size():
		return "æ¼å‹º%dï¼šç©º" % ladle_index

	return get_staple_ladle_text(slot_index)


func request_cart_pot_panel_refresh() -> void:
	panel_controller.request_refresh()


func refresh_cart_pot_panel() -> void:
	panel_controller.refresh()


func close_cart_pot_panel_and_auto_start() -> void:
	if cart_pot_is_cooking:
		print("å¤§é”…æ­£åœ¨çƒ¹é¥ªä¸­ï¼Œå…³é—­é¢æ¿ã€‚")
		close_cart_pot_panel()
		return

	if cart_pot_selection.is_empty():
		print("æ²¡æœ‰é€‰æ‹©è¦ç…®çš„é…èœï¼Œå…³é—­å¤§é”…é¢æ¿ã€‚")
		close_cart_pot_panel()
		return

	print("å…³é—­å¤§é”…é¢æ¿ï¼Œè‡ªåŠ¨å¼€å§‹çƒ¹é¥ªã€‚")
	start_cart_pot_batch_cooking()
	close_cart_pot_panel()


func close_cart_pot_panel() -> void:
	panel_controller.close()


func _on_cart_pot_minus_pressed(item_id: String) -> void:
	if cart_pot_is_cooking:
		print("å¤§é”…æ­£åœ¨ç…®ï¼Œä¸èƒ½è°ƒæ•´æœ¬æ¬¡å‡†å¤‡ã€‚")
		request_cart_pot_panel_refresh()
		return

	var current_amount := int(cart_pot_selection.get(item_id, 0))

	if current_amount <= 0:
		cart_pot_selection.erase(item_id)
		request_cart_pot_panel_refresh()
		return

	current_amount -= 1

	if current_amount <= 0:
		cart_pot_selection.erase(item_id)
	else:
		cart_pot_selection[item_id] = current_amount

	request_cart_pot_panel_refresh()


func _on_cart_pot_plus_pressed(item_id: String) -> void:
	if cart_pot_is_cooking:
		print("å¤§é”…æ­£åœ¨ç…®ï¼Œä¸èƒ½è°ƒæ•´æœ¬æ¬¡å‡†å¤‡ã€‚")
		request_cart_pot_panel_refresh()
		return

	if not can_add_to_cart_pot_selection(item_id, 1):
		print("ä¸èƒ½ç»§ç»­åŠ å…¥å¤§é”…é€‰æ‹©ï¼š", item_id)
		request_cart_pot_panel_refresh()
		return

	cart_pot_selection[item_id] = int(cart_pot_selection.get(item_id, 0)) + 1

	request_cart_pot_panel_refresh()


func _on_cart_pot_max_pressed(item_id: String) -> void:
	if cart_pot_is_cooking:
		print("å¤§é”…æ­£åœ¨ç…®ï¼Œä¸èƒ½è°ƒæ•´æœ¬æ¬¡å‡†å¤‡ã€‚")
		request_cart_pot_panel_refresh()
		return

	var raw_amount: int = int(manager.raw_stock.get(item_id, 0))
	var selected_amount: int = int(cart_pot_selection.get(item_id, 0))
	var available_capacity: int = int(get_cart_pot_available_capacity_for_selection())

	var raw_available: int = raw_amount - selected_amount
	var can_add_amount: int = min(raw_available, available_capacity)

	if can_add_amount <= 0:
		print("æ²¡æœ‰æ›´å¤šå¯åŠ å…¥å¤§é”…çš„æ•°é‡ï¼š", item_id)
		request_cart_pot_panel_refresh()
		return

	cart_pot_selection[item_id] = selected_amount + can_add_amount

	request_cart_pot_panel_refresh()


func _on_cart_pot_start_pressed() -> void:
	start_cart_pot_batch_cooking()


func get_cart_pot_ingredient_ids() -> Array:
	var ids: Array = RunSetupData.get_basic_ingredient_ids()

	if ids.is_empty():
		ids = [
			"spinach",
			"potato_slice",
			"tofu_puff"
		]

	return ids


func get_cart_pot_cooked_capacity_used() -> int:
	return manager.get_stock_total(manager.cooked_stock)


func get_cart_pot_cooking_capacity_used() -> int:
	return manager.get_stock_total(cart_pot_cooking_batch)


func get_cart_pot_selection_total() -> int:
	return manager.get_stock_total(cart_pot_selection)


func get_cart_pot_used_capacity() -> int:
	return get_cart_pot_cooked_capacity_used() + get_cart_pot_cooking_capacity_used()


func get_cart_pot_total_capacity_with_selection() -> int:
	return get_cart_pot_used_capacity() + get_cart_pot_selection_total()


func get_cart_pot_available_capacity_for_selection() -> int:
	return max(cart_pot_capacity - get_cart_pot_total_capacity_with_selection(), 0)


func can_add_to_cart_pot_selection(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false

	if cart_pot_is_cooking:
		return false

	var current_selected := int(cart_pot_selection.get(item_id, 0))
	var current_raw := int(manager.raw_stock.get(item_id, 0))

	if current_selected + amount > current_raw:
		return false

	if get_cart_pot_total_capacity_with_selection() + amount > cart_pot_capacity:
		return false

	return true


func add_to_cart_pot_selection(item_id: String, amount: int = 1) -> void:
	if amount <= 0:
		return

	var actually_added := 0

	for i in range(amount):
		if not can_add_to_cart_pot_selection(item_id, 1):
			break

		cart_pot_selection[item_id] = int(cart_pot_selection.get(item_id, 0)) + 1
		actually_added += 1

	if actually_added > 0:
		refresh_cart_pot_panel()


func remove_from_cart_pot_selection(item_id: String, amount: int = 1) -> void:
	if amount <= 0:
		return

	var current_selected := int(cart_pot_selection.get(item_id, 0))
	current_selected = max(current_selected - amount, 0)

	if current_selected <= 0:
		cart_pot_selection.erase(item_id)
	else:
		cart_pot_selection[item_id] = current_selected

	refresh_cart_pot_panel()


func max_add_to_cart_pot_selection(item_id: String) -> void:
	if cart_pot_is_cooking:
		return

	var current_selected: int = int(cart_pot_selection.get(item_id, 0))
	var current_raw: int = int(manager.raw_stock.get(item_id, 0))

	var raw_room: int = current_raw - current_selected
	if raw_room < 0:
		raw_room = 0

	var capacity_room: int = get_cart_pot_available_capacity_for_selection()

	var amount: int = raw_room
	if capacity_room < amount:
		amount = capacity_room

	if amount <= 0:
		return

	add_to_cart_pot_selection(item_id, amount)


func start_cart_pot_batch_cooking() -> void:
	if cart_pot_is_cooking:
		print("å¤§é”…å·²ç»åœ¨ç…®äº†ã€‚")
		return

	if cart_pot_selection.is_empty():
		print("æ²¡æœ‰é€‰æ‹©è¦ç…®çš„é…èœã€‚")
		return

	var batch: Dictionary = {}

	for item_id in cart_pot_selection.keys():
		var item_key: String = str(item_id)
		var amount: int = int(cart_pot_selection.get(item_key, 0))

		if amount <= 0:
			continue

		var raw_amount: int = int(manager.raw_stock.get(item_key, 0))

		if raw_amount <= 0:
			continue

		var actual_amount: int = min(amount, raw_amount)

		if actual_amount <= 0:
			continue

		batch[item_key] = actual_amount

	if batch.is_empty():
		print("æœ¬æ¬¡é€‰æ‹©æ²¡æœ‰å¯ç…®çš„é…èœã€‚")
		cart_pot_selection.clear()
		refresh_cart_pot_panel()
		return

	if get_cart_pot_total_capacity_with_selection() > cart_pot_capacity:
		print("å¤§é”…å®¹é‡ä¸è¶³ï¼Œä¸èƒ½å¼€å§‹ç…®ã€‚")
		refresh_cart_pot_panel()
		return

	for item_id in batch.keys():
		var item_key: String = str(item_id)
		var amount: int = int(batch.get(item_key, 0))
		manager.raw_stock[item_key] = int(manager.raw_stock.get(item_key, 0)) - amount

	cart_pot_is_cooking = true
	cart_pot_cooking_batch = batch.duplicate(true)
	cart_pot_time_left = get_effective_cart_pot_batch_duration()
	cart_pot_selection.clear()

	RunSetupData.current_raw_stock = manager.raw_stock.duplicate(true)

	print("=== å¤§é”…å¼€å§‹æ‰¹é‡çƒ¹é¥ª ===")
	print("Batch: ", cart_pot_cooking_batch)
	print("å¤§é”…æœ¬æ¬¡çƒ¹é¥ªæ—¶é—´ï¼š", cart_pot_time_left)
	print("Raw stock after starting cart pot: ", manager.raw_stock)
	print("Cart pot capacity used: %d/%d" % [
		get_cart_pot_total_capacity_with_selection(),
		cart_pot_capacity
	])

	refresh_cart_pot_panel()


func update_cart_pot(delta: float) -> void:
	if not cart_pot_is_cooking:
		return

	cart_pot_time_left -= delta

	if cart_pot_time_left > 0.0:
		if panel_controller.is_open():
			refresh_cart_pot_panel()
		return

	finish_cart_pot_batch_cooking()


func finish_cart_pot_batch_cooking() -> void:
	if not cart_pot_is_cooking:
		return

	for item_id in cart_pot_cooking_batch.keys():
		var item_key := str(item_id)
		var amount := int(cart_pot_cooking_batch.get(item_key, 0))

		if amount <= 0:
			continue

		if not manager.cooked_stock.has(item_key):
			manager.cooked_stock[item_key] = 0

		manager.cooked_stock[item_key] = int(manager.cooked_stock.get(item_key, 0)) + amount

	print("=== å¤§é”…æ‰¹é‡çƒ¹é¥ªå®Œæˆ ===")
	print("Cooked batch: ", cart_pot_cooking_batch)

	cart_pot_is_cooking = false
	cart_pot_time_left = 0.0
	cart_pot_cooking_batch.clear()

	RunSetupData.current_cooked_stock = manager.cooked_stock.duplicate(true)

	print("Cooked stock after cart pot: ", manager.cooked_stock)
	print("Cart pot capacity used: ", get_cart_pot_used_capacity(), "/", cart_pot_capacity)

	refresh_cart_pot_panel()
	manager.print_stocks()


func initialize_staple_ladle_slots() -> void:
	staple_ladle_slots.clear()

	for i in range(2):
		staple_ladle_slots.append({
			"state": "empty",
			"main_food_id": "",
			"time_left": 0.0
		})

	held_raw_staple_food_id = ""
	held_staple_food_id = ""


func has_busy_staple_ladle() -> bool:
	for i in range(staple_ladle_slots.size()):
		var slot: Dictionary = staple_ladle_slots[i] as Dictionary
		var state: String = str(slot.get("state", "empty"))

		if state == "cooking":
			return true

	return false


func update_staple_ladle_slots(delta: float) -> void:
	if staple_ladle_slots.is_empty():
		return

	var changed := false

	for i in range(staple_ladle_slots.size()):
		var slot: Dictionary = staple_ladle_slots[i] as Dictionary
		var state: String = str(slot.get("state", "empty"))

		if state != "cooking":
			continue

		var time_left: float = float(slot.get("time_left", 0.0))
		time_left -= delta

		if time_left <= 0.0:
			slot["state"] = "ready"
			slot["time_left"] = 0.0
			print("æ¼å‹º ", i + 1, " çš„ ", manager.get_ingredient_display_name(str(slot.get("main_food_id", ""))), " ç…®å¥½äº†ã€‚")
		else:
			slot["time_left"] = time_left

		staple_ladle_slots[i] = slot
		changed = true

	if changed and panel_controller.is_open():
		refresh_cart_pot_panel()


func get_first_pending_customer_waiting_for_main_food(main_food_id: String) -> Node:
	for customer in manager.pending_order_system.get_all():
		if customer == null or not is_instance_valid(customer):
			continue

		if CustomerOrderState.is_served(customer):
			continue

		if CustomerOrderState.needs_emergency_purchase(customer):
			continue

		if not manager.customer_has_main_food(customer):
			continue

		if manager.get_customer_main_food_stock_id(customer) != main_food_id:
			continue

		if not CustomerOrderState.needs_main_food(customer):
			continue

		return customer

	return null


func has_waiting_main_food_order(main_food_id: String) -> bool:
	return get_unassigned_waiting_main_food_count(main_food_id) > 0


func get_waiting_main_food_count(main_food_id: String) -> int:
	var count := 0

	for customer in manager.pending_order_system.get_all():
		if customer == null or not is_instance_valid(customer):
			continue

		if CustomerOrderState.is_served(customer):
			continue

		if CustomerOrderState.needs_emergency_purchase(customer):
			continue

		if not manager.customer_has_main_food(customer):
			continue

		if manager.get_customer_main_food_stock_id(customer) != main_food_id:
			continue

		if not CustomerOrderState.needs_main_food(customer):
			continue

		count += 1

	return count


func get_assigned_staple_food_count(main_food_id: String) -> int:
	var count: int = 0

	for i in range(staple_ladle_slots.size()):
		var slot: Dictionary = staple_ladle_slots[i] as Dictionary
		var state: String = str(slot.get("state", "empty"))
		var slot_food_id: String = str(slot.get("main_food_id", ""))

		if state == "empty":
			continue

		if slot_food_id == main_food_id:
			count += 1

	if held_staple_food_id == main_food_id:
		count += 1

	return count


func get_unassigned_waiting_main_food_count(main_food_id: String) -> int:
	var waiting_count: int = get_waiting_main_food_count(main_food_id)
	var assigned_count: int = get_assigned_staple_food_count(main_food_id)

	var available_count: int = waiting_count - assigned_count
	if available_count < 0:
		available_count = 0

	return available_count


func can_start_staple_ladle_cooking(slot_index: int, main_food_id: String) -> bool:
	if slot_index < 0 or slot_index >= staple_ladle_slots.size():
		return false

	if main_food_id == "":
		return false

	if not RunSetupData.is_staple_item(main_food_id):
		return false

	var slot: Dictionary = staple_ladle_slots[slot_index] as Dictionary
	var state: String = str(slot.get("state", "empty"))

	if state != "empty":
		return false

	var current_stock: int = int(manager.staple_stock.get(main_food_id, 0))

	if current_stock <= 0:
		return false

	return true


func start_staple_ladle_cooking(slot_index: int, main_food_id: String) -> void:
	if not can_start_staple_ladle_cooking(slot_index, main_food_id):
		print("ä¸èƒ½å¼€å§‹ç…®ä¸»é£Ÿï¼š", main_food_id, " slot=", slot_index)
		return

	var slot: Dictionary = staple_ladle_slots[slot_index] as Dictionary

	slot["state"] = "cooking"
	slot["main_food_id"] = main_food_id
	slot["time_left"] = get_effective_staple_ladle_duration()
	slot["is_ready"] = false
	staple_ladle_slots[slot_index] = slot

	manager.staple_stock[main_food_id] = int(manager.staple_stock.get(main_food_id, 0)) - 1
	RunSetupData.current_staple_stock = manager.staple_stock.duplicate(true)

	print("æ¼å‹º ", slot_index + 1, " å¼€å§‹ç…®ï¼š", manager.get_ingredient_display_name(main_food_id))
	print("æ¼å‹ºæœ¬æ¬¡çƒ¹é¥ªæ—¶é—´ï¼š", slot["time_left"])
	print("Staple stock after putting into ladle: ", manager.staple_stock)

	request_cart_pot_panel_refresh()


func take_ready_staple_from_ladle(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= staple_ladle_slots.size():
		return

	if held_staple_food_id != "":
		print("æ‰‹é‡Œå·²ç»æœ‰ä¸»é£Ÿï¼š", manager.get_ingredient_display_name(held_staple_food_id), "ã€‚å…ˆåŽ»å‡ºé¤ç‚¹äº¤ä»˜ã€‚")
		return

	var slot: Dictionary = staple_ladle_slots[slot_index] as Dictionary
	var state: String = str(slot.get("state", "empty"))

	if state != "ready":
		print("æ¼å‹º ", slot_index + 1, " è¿˜æ²¡æœ‰å¯ä»¥å–å‡ºçš„ä¸»é£Ÿã€‚")
		return

	var main_food_id: String = str(slot.get("main_food_id", ""))

	if main_food_id == "":
		return

	held_staple_food_id = main_food_id

	slot["state"] = "empty"
	slot["main_food_id"] = ""
	slot["time_left"] = 0.0
	staple_ladle_slots[slot_index] = slot

	print("ä»Žæ¼å‹º ", slot_index + 1, " å–å‡ºï¼š", manager.get_ingredient_display_name(main_food_id), "ã€‚çŽ°åœ¨æ‰‹é‡Œæ‹¿ç€è¿™ä»½ä¸»é£Ÿã€‚")

	refresh_cart_pot_panel()


func interact_with_staple_basket(main_food_id: String) -> void:
	if main_food_id == "":
		print("æ²¡æœ‰æŒ‡å®šä¸»é£Ÿç­ã€‚")
		return

	if not RunSetupData.is_staple_item(main_food_id):
		print("è¿™ä¸æ˜¯å¯ç”¨ä¸»é£Ÿï¼š", main_food_id)
		return

	var display_name: String = manager.get_ingredient_display_name(main_food_id)

	if held_staple_food_id != "":
		print("æ‰‹é‡Œå·²ç»æ‹¿ç€ç†Ÿä¸»é£Ÿï¼š", manager.get_ingredient_display_name(held_staple_food_id), "ã€‚å…ˆåŽ»å‡ºé¤ç‚¹äº¤ä»˜ã€‚")
		return

	if held_raw_staple_food_id == "":
		var current_stock: int = int(manager.staple_stock.get(main_food_id, 0))

		if current_stock <= 0:
			print(display_name, " åº“å­˜ä¸è¶³ï¼Œä¸èƒ½æ‹¿èµ·ã€‚")
			return

		held_raw_staple_food_id = main_food_id
		print("æ‹¿èµ·ç”Ÿä¸»é£Ÿï¼š", display_name, "ã€‚æ­¤æ—¶ä¸æ‰£åº“å­˜ã€‚")
		print("å½“å‰ä¸»é£Ÿåº“å­˜ï¼š", manager.staple_stock)
		return

	if held_raw_staple_food_id == main_food_id:
		print("æŠŠç”Ÿä¸»é£Ÿæ”¾å›žï¼š", display_name, "ã€‚å› ä¸ºè¿˜æ²¡ä¸‹æ¼å‹ºï¼Œæ‰€ä»¥ä¸æ‰£åº“å­˜ã€‚")
		held_raw_staple_food_id = ""
		return

	print("æ‰‹é‡Œæ‹¿ç€çš„æ˜¯ï¼š", manager.get_ingredient_display_name(held_raw_staple_food_id), "ã€‚è¦å›žå¯¹åº”ä¸»é£Ÿç­æ‰èƒ½æ”¾å›žã€‚")


func interact_with_staple_ladle(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= staple_ladle_slots.size():
		print("æ¼å‹ºç¼–å·ä¸å­˜åœ¨ï¼š", slot_index)
		return

	var slot: Dictionary = staple_ladle_slots[slot_index] as Dictionary
	var state: String = str(slot.get("state", "empty"))

	if state == "empty":
		if held_raw_staple_food_id == "":
			print("æ¼å‹º ", slot_index + 1, " æ˜¯ç©ºçš„ã€‚å…ˆåŽ»ç²‰ä¸ç­æˆ–é¢ç­æ‹¿ç”Ÿä¸»é£Ÿã€‚")
			return

		if held_staple_food_id != "":
			print("æ‰‹é‡Œå·²ç»æ‹¿ç€ç†Ÿä¸»é£Ÿï¼š", manager.get_ingredient_display_name(held_staple_food_id), "ã€‚å…ˆåŽ»å‡ºé¤ç‚¹äº¤ä»˜ã€‚")
			return

		var main_food_id: String = held_raw_staple_food_id

		if not can_start_staple_ladle_cooking(slot_index, main_food_id):
			print("ä¸èƒ½æŠŠ ", manager.get_ingredient_display_name(main_food_id), " æ”¾å…¥æ¼å‹º ", slot_index + 1, "ã€‚")
			return

		start_staple_ladle_cooking(slot_index, main_food_id)
		held_raw_staple_food_id = ""
		print("å·²ç»æŠŠç”Ÿä¸»é£Ÿæ”¾å…¥æ¼å‹º ", slot_index + 1, "ã€‚è¿™æ—¶æ‰æ‰£åº“å­˜ã€‚")
		return

	if state == "cooking":
		var cooking_food_id: String = str(slot.get("main_food_id", ""))
		var time_left: float = float(slot.get("time_left", 0.0))
		print("æ¼å‹º ", slot_index + 1, " æ­£åœ¨ç…® ", manager.get_ingredient_display_name(cooking_food_id), "ï¼Œè¿˜å‰© %.1f ç§’ã€‚" % time_left)
		return

	if state == "ready":
		if held_raw_staple_food_id != "":
			print("æ‰‹é‡Œè¿˜æ‹¿ç€ç”Ÿä¸»é£Ÿï¼š", manager.get_ingredient_display_name(held_raw_staple_food_id), "ã€‚å…ˆæ”¾å›žä¸»é£Ÿç­ï¼Œæˆ–è€…æ‰¾ç©ºæ¼å‹ºä¸‹é”…ã€‚")
			return

		take_ready_staple_from_ladle(slot_index)
		return

	print("æ¼å‹º ", slot_index + 1, " çŠ¶æ€å¼‚å¸¸ï¼š", state)


func get_held_raw_staple_text() -> String:
	if held_raw_staple_food_id == "":
		return "ç©º"
	return manager.get_ingredient_display_name(held_raw_staple_food_id)


func get_held_staple_text() -> String:
	if held_staple_food_id == "":
		return "ç©º"

	return manager.get_ingredient_display_name(held_staple_food_id)


func get_staple_ladle_text(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= staple_ladle_slots.size():
		return "æ¼å‹ºä¸å­˜åœ¨"

	var slot: Dictionary = staple_ladle_slots[slot_index] as Dictionary
	var state: String = str(slot.get("state", "empty"))
	var main_food_id: String = str(slot.get("main_food_id", ""))
	var main_food_text := "æ— "

	if main_food_id != "":
		main_food_text = manager.get_ingredient_display_name(main_food_id)

	if state == "empty":
		return "æ¼å‹º %dï¼šç©º" % [slot_index + 1]

	if state == "cooking":
		return "æ¼å‹º %dï¼šæ­£åœ¨ç…® %sï¼Œå‰©ä½™ %.1f ç§’" % [
			slot_index + 1,
			main_food_text,
			float(slot.get("time_left", 0.0))
		]

	if state == "ready":
		return "æ¼å‹º %dï¼š%s å·²ç…®å¥½ï¼Œç­‰å¾…å–å‡º" % [
			slot_index + 1,
			main_food_text
		]

	return "æ¼å‹º %dï¼šæœªçŸ¥çŠ¶æ€" % [slot_index + 1]


func get_cart_ingredients_needed_from_pot(customer: Node) -> Dictionary:
	if customer == null or not is_instance_valid(customer):
		return {}

	var ingredients_to_cook := CustomerOrderState.get_ingredients_to_cook(customer)
	if not ingredients_to_cook.is_empty():
		return ingredients_to_cook

	if CustomerOrderState.were_ingredients_deducted_at_checkout(customer):
		return {}

	if customer.has_method("get_ingredients"):
		return customer.get_ingredients()

	return {}


func get_cart_ingredient_shortage_for_customer(customer: Node) -> Dictionary:
	var shortage: Dictionary = {}

	if customer == null or not is_instance_valid(customer):
		return shortage

	if CustomerOrderState.is_served(customer):
		return shortage

	if not CustomerOrderState.needs_ingredients(customer):
		return shortage

	if CustomerOrderState.is_ingredients_ready(customer):
		return shortage

	var needed_ingredients: Dictionary = get_cart_ingredients_needed_from_pot(customer)

	if needed_ingredients.is_empty():
		return shortage

	for item_id in needed_ingredients.keys():
		var item_key: String = str(item_id)
		var needed_amount: int = int(needed_ingredients.get(item_key, 0))
		var cooked_amount: int = int(manager.cooked_stock.get(item_key, 0))
		var missing_amount: int = needed_amount - cooked_amount

		if missing_amount > 0:
			shortage[item_key] = missing_amount

	return shortage


func try_fulfill_cart_ingredients_for_customer(customer: Node) -> bool:
	if customer == null or not is_instance_valid(customer):
		return false

	if CustomerOrderState.is_served(customer):
		return false

	if CustomerOrderState.needs_emergency_purchase(customer):
		print("é¡¾å®¢è®¢å•è¿˜åœ¨ç¼ºè´§ï¼Œå…ˆåŽ»åº”æ€¥é‡‡è´­ã€‚")
		return false

	if not CustomerOrderState.needs_ingredients(customer):
		return false

	if CustomerOrderState.is_ingredients_ready(customer):
		return false

	var needed_ingredients: Dictionary = get_cart_ingredients_needed_from_pot(customer)

	if needed_ingredients.is_empty():
		CustomerOrderState.mark_ingredients_ready(customer)
		return true

	if not manager.can_fulfill_from_cooked(needed_ingredients):
		print("é”…ä¸­ç†Ÿé…èœä¸è¶³ï¼Œéœ€è¦ç»§ç»­ç…®ã€‚ç¼ºå£ï¼š", get_cart_ingredient_shortage_for_customer(customer))
		return false

	manager.deduct_cooked_stock(needed_ingredients)

	CustomerOrderState.set_ingredients_to_cook(customer, {})
	CustomerOrderState.set_ingredients_deducted_at_checkout(customer, true)

	CustomerOrderState.mark_ingredients_ready(customer)

	print("å·²ä»Žå¤§é”…æäº¤é…èœç»™é¡¾å®¢ï¼š", needed_ingredients)
	manager.print_stocks()

	if panel_controller.is_open():
		refresh_cart_pot_panel()

	return true


func refresh_cart_ingredients_for_pending_customers() -> void:
	for customer in manager.pending_order_system.get_all():
		if customer == null or not is_instance_valid(customer):
			continue

		if CustomerOrderState.is_served(customer):
			continue

		if CustomerOrderState.needs_emergency_purchase(customer):
			continue

		if CustomerOrderState.needs_ingredients(customer):
			try_fulfill_cart_ingredients_for_customer(customer)


func hand_over_held_staple_to_waiting_customer() -> Node:
	if held_staple_food_id == "":
		return null

	var held_food_id: String = held_staple_food_id
	var held_food_name: String = manager.get_ingredient_display_name(held_food_id)

	for customer in manager.pending_order_system.get_all():
		if customer == null or not is_instance_valid(customer):
			continue

		if CustomerOrderState.is_served(customer):
			continue

		if not manager.customer_has_main_food(customer):
			continue

		if not CustomerOrderState.needs_main_food(customer):
			continue

		if CustomerOrderState.is_main_food_ready(customer):
			continue

		var customer_main_food: String = str(customer.get_main_food())

		if customer_main_food != held_food_name and customer_main_food != held_food_id:
			continue

		CustomerOrderState.mark_main_food_ready(customer)
		held_staple_food_id = ""

		print("Customer main food is ready.")
		print("äº¤å‡ºæ‰‹ä¸­ä¸»é£Ÿï¼š", held_food_name)

		return customer

	print("æ‰‹é‡Œæœ‰ä¸»é£Ÿï¼Œä½†æ²¡æœ‰ç­‰å¾…è¿™ç§ä¸»é£Ÿçš„é¡¾å®¢ï¼š", held_food_name)
	return null


func has_busy_cooking() -> bool:
	return has_busy_staple_ladle() or cart_pot_is_cooking


func clear_day_end_state() -> Dictionary:
	var discarded: Dictionary = {
		"held_raw": "",
		"held": "",
		"ladles": []
	}

	if held_raw_staple_food_id != "":
		discarded["held_raw"] = held_raw_staple_food_id
		held_raw_staple_food_id = ""

	if held_staple_food_id != "":
		discarded["held"] = held_staple_food_id
		held_staple_food_id = ""

	for i in range(staple_ladle_slots.size()):
		var slot: Dictionary = staple_ladle_slots[i] as Dictionary
		var state := str(slot.get("state", "empty"))
		var main_food_id := str(slot.get("main_food_id", ""))

		if state != "empty" or main_food_id != "":
			discarded["ladles"].append({
				"slot": i,
				"state": state,
				"main_food_id": main_food_id
			})

		slot["state"] = "empty"
		slot["main_food_id"] = ""
		slot["time_left"] = 0.0
		slot["is_ready"] = false
		staple_ladle_slots[i] = slot

	return discarded


func get_effective_cart_pot_batch_duration() -> float:
	var duration: float = cart_pot_batch_duration

	if manager.has_effect("claw_dance"):
		duration *= 0.8

	return max(duration, 0.2)


func get_effective_staple_ladle_duration() -> float:
	var duration: float = staple_ladle_duration

	if manager.has_effect("claw_dance"):
		duration *= 0.8

	return max(duration, 0.2)
