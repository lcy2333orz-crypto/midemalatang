class_name CookingSystem

extends RefCounted



const CustomerOrderState = preload("res://gameplay/models/customer_order_state.gd")

const CartPotPanelControllerScript = preload("res://scenes/ui/cart_pot_panel_controller.gd")



var manager = null

var panel_controller: CartPotPanelController = null



var cart_pot_capacity: int = 6

var cart_pot_batch_duration: float = 3.0

var cart_pot_cooking_batches: Array = []

var cart_pot_selection: Dictionary = {}



var staple_ladle_duration: float = 3.0

var staple_ladle_slots: Array = []

var held_raw_staple_food_id: String = ""

var held_staple_food_id: String = ""

var held_disposable_plate: bool = false

var cooker_slots: Array = []





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



	if typeof(cart_pot_cooking_batches) != TYPE_ARRAY:

		warnings.append("CookingSystem: cart_pot_cooking_batches is not an Array.")



	for batch in cart_pot_cooking_batches:

		if typeof(batch) != TYPE_DICTIONARY:

			warnings.append("CookingSystem: cart_pot_cooking_batches contains a non-Dictionary batch.")

			continue



		if typeof(batch.get("items", {})) != TYPE_DICTIONARY:

			warnings.append("CookingSystem: cart pot batch items is not a Dictionary.")



		if float(batch.get("time_left", 0.0)) < 0.0:

			warnings.append("CookingSystem: cart pot batch time_left is negative.")



	if typeof(cooker_slots) != TYPE_ARRAY:

		warnings.append("CookingSystem: cooker_slots is not an Array.")



	_append_cart_pot_business_warnings(warnings)
	_append_staple_ladle_business_warnings(warnings)
	_append_cooker_slot_business_warnings(warnings)

	return warnings


func _append_cart_pot_business_warnings(warnings: Array[String]) -> void:
	if cart_pot_capacity <= 0:
		warnings.append("CookingSystem: cart_pot_capacity must be positive.")

	var used_capacity: int = get_cart_pot_total_capacity_with_selection()
	if used_capacity > cart_pot_capacity:
		warnings.append("CookingSystem: cart pot capacity is overfilled: %d/%d." % [used_capacity, cart_pot_capacity])

	for item_id in cart_pot_selection.keys():
		var item_key: String = str(item_id)
		var amount: int = int(cart_pot_selection.get(item_key, 0))
		if amount <= 0:
			warnings.append("CookingSystem: cart_pot_selection contains a non-positive amount for %s." % item_key)
		if amount > int(manager.raw_stock.get(item_key, 0)):
			warnings.append("CookingSystem: cart_pot_selection exceeds raw stock for %s." % item_key)

	for batch in cart_pot_cooking_batches:
		if typeof(batch) != TYPE_DICTIONARY:
			continue

		var items = batch.get("items", {})
		if typeof(items) != TYPE_DICTIONARY:
			continue

		var item_dict: Dictionary = items as Dictionary
		if item_dict.is_empty():
			warnings.append("CookingSystem: cart pot batch has no items.")

		for item_id in item_dict.keys():
			var amount: int = int(item_dict.get(item_id, 0))
			if amount <= 0:
				warnings.append("CookingSystem: cart pot batch contains a non-positive amount for %s." % str(item_id))


func _append_staple_ladle_business_warnings(warnings: Array[String]) -> void:
	if held_raw_staple_food_id != "" and not RunSetupData.is_staple_item(held_raw_staple_food_id):
		warnings.append("CookingSystem: held_raw_staple_food_id is not a configured staple item.")

	if held_staple_food_id != "" and not RunSetupData.is_staple_item(held_staple_food_id):
		warnings.append("CookingSystem: held_staple_food_id is not a configured staple item.")

	if held_raw_staple_food_id != "" and held_staple_food_id != "":
		warnings.append("CookingSystem: raw and cooked staple are both held.")

	for i in range(staple_ladle_slots.size()):
		var slot: Dictionary = staple_ladle_slots[i] as Dictionary
		var state: String = str(slot.get("state", "empty"))
		var main_food_id: String = str(slot.get("main_food_id", ""))
		var time_left: float = float(slot.get("time_left", 0.0))

		if not ["empty", "cooking", "ready"].has(state):
			warnings.append("CookingSystem: staple ladle %d has an unknown state: %s." % [i, state])

		if state == "empty":
			if main_food_id != "":
				warnings.append("CookingSystem: empty staple ladle %d still has a main_food_id." % i)
			if time_left != 0.0:
				warnings.append("CookingSystem: empty staple ladle %d has non-zero time_left." % i)
			continue

		if main_food_id == "" or not RunSetupData.is_staple_item(main_food_id):
			warnings.append("CookingSystem: staple ladle %d has an invalid main_food_id." % i)

		if state == "cooking" and time_left <= 0.0:
			warnings.append("CookingSystem: cooking staple ladle %d has non-positive time_left." % i)

		if state == "ready" and time_left != 0.0:
			warnings.append("CookingSystem: ready staple ladle %d has non-zero time_left." % i)


func _append_cooker_slot_business_warnings(warnings: Array[String]) -> void:
	if manager.unlocked_cooker_slots < 0:
		warnings.append("CookingSystem: unlocked_cooker_slots is negative.")

	if manager.unlocked_cooker_slots > cooker_slots.size():
		warnings.append("CookingSystem: unlocked_cooker_slots exceeds cooker_slots size.")

	for i in range(cooker_slots.size()):
		var slot: Dictionary = cooker_slots[i] as Dictionary
		var is_busy: bool = bool(slot.get("is_busy", false))
		var customer = slot.get("customer", null)
		var time_left: float = float(slot.get("time_left", 0.0))

		if is_busy:
			if customer == null or not is_instance_valid(customer):
				warnings.append("CookingSystem: busy cooker slot %d has no valid customer." % i)
			if time_left <= 0.0:
				warnings.append("CookingSystem: busy cooker slot %d has non-positive time_left." % i)
			if i >= manager.unlocked_cooker_slots:
				warnings.append("CookingSystem: locked cooker slot %d is busy." % i)
		else:
			if customer != null and is_instance_valid(customer):
				warnings.append("CookingSystem: idle cooker slot %d still has a customer." % i)
			if time_left != 0.0:
				warnings.append("CookingSystem: idle cooker slot %d has non-zero time_left." % i)





func update(delta: float) -> void:

	update_cooker_slots(delta)

	update_cart_pot(delta)

	update_staple_ladle_slots(delta)





func open_cart_pot_panel() -> void:

	panel_controller.open()





func initialize_cooker_slots() -> void:

	cooker_slots.clear()

	for i in range(manager.total_cooker_slots):

		cooker_slots.append({

			"is_busy": false,

			"customer": null,

			"time_left": 0.0

		})





func update_cooker_slots(delta: float) -> void:

	for i in range(cooker_slots.size()):

		var slot = cooker_slots[i]



		if not slot["is_busy"]:

			continue



		slot["time_left"] -= delta



		if slot["time_left"] > 0.0:

			cooker_slots[i] = slot

			continue



		var customer = slot["customer"]

		if customer != null and is_instance_valid(customer):

			customer.mark_food_ready()

			print("Cooking finished in slot ", i, ". Order is ready for delivery.")

			print("This cooked food belongs to this customer and is not added to public cooked_stock.")

			manager.inventory_system.print_stocks()



		slot["is_busy"] = false

		slot["customer"] = null

		slot["time_left"] = 0.0

		cooker_slots[i] = slot





func is_customer_in_any_cooker(customer: Node) -> bool:

	for i in range(min(manager.unlocked_cooker_slots, cooker_slots.size())):

		var slot = cooker_slots[i]

		if slot["is_busy"] and slot["customer"] == customer:

			return true

	return false





func find_free_cooker_slot_index() -> int:

	for i in range(min(manager.unlocked_cooker_slots, cooker_slots.size())):

		var slot = cooker_slots[i]

		if not slot["is_busy"]:

			return i

	return -1





func get_customer_cooker_slot_index(customer: Node) -> int:

	for i in range(min(manager.unlocked_cooker_slots, cooker_slots.size())):

		var slot = cooker_slots[i]

		if slot["is_busy"] and slot["customer"] == customer:

			return i

	return -1





func remove_customer_from_cooker_slots(customer: Node) -> void:

	for i in range(cooker_slots.size()):

		var slot = cooker_slots[i]

		if slot["customer"] == customer:

			slot["is_busy"] = false

			slot["customer"] = null

			slot["time_left"] = 0.0

			cooker_slots[i] = slot





func start_shop_order_bound_cooking_pending_order() -> void:

	var customer: Node = manager.pending_order_system.get_first_uncooked() as Node



	if customer == null:

		if manager.emergency_purchase_system.get_first_customer_needing_purchase() != null:

			print("Need emergency purchase first.")

		else:

			print("No pending order to cook")

		return



	var free_slot_index: int = find_free_cooker_slot_index()



	if free_slot_index == -1:

		print("All unlocked cookers are busy")

		return



	var slot: Dictionary = cooker_slots[free_slot_index] as Dictionary

	slot["is_busy"] = true

	slot["customer"] = customer

	slot["time_left"] = manager.cooker_duration

	cooker_slots[free_slot_index] = slot



	print("Start cooking customer in slot ", free_slot_index, ": ", customer)





func has_busy_order_bound_cooker() -> bool:

	for i in range(min(manager.unlocked_cooker_slots, cooker_slots.size())):

		var slot: Dictionary = cooker_slots[i] as Dictionary



		if bool(slot.get("is_busy", false)):

			return true



	return false





func _build_ladle_row(ladle_index: int) -> HBoxContainer:

	var slot_index: int = ladle_index - 1



	var row: HBoxContainer = HBoxContainer.new()

	row.add_theme_constant_override("separation", 8)



	var state_label: Label = Label.new()

	state_label.custom_minimum_size = Vector2(190, 28)

	state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	state_label.text = _get_ladle_state_text(ladle_index)

	row.add_child(state_label)



	var slot_state: String = "empty"



	if slot_index >= 0 and slot_index < staple_ladle_slots.size():

		var slot: Dictionary = staple_ladle_slots[slot_index] as Dictionary

		slot_state = str(slot.get("state", "empty"))



	var cook_glass_button: Button = Button.new()

	cook_glass_button.text = TextDB.get_text("UI_STAPLE_LADLE_COOK_ITEM") % TextDB.get_item_name("glass_noodle")

	cook_glass_button.custom_minimum_size = Vector2(74, 28)

	cook_glass_button.disabled = not can_start_staple_ladle_cooking(slot_index, "glass_noodle")

	row.add_child(cook_glass_button)



	var cook_noodle_button: Button = Button.new()

	cook_noodle_button.text = TextDB.get_text("UI_STAPLE_LADLE_COOK_ITEM") % TextDB.get_item_name("noodle")

	cook_noodle_button.custom_minimum_size = Vector2(74, 28)

	cook_noodle_button.disabled = not can_start_staple_ladle_cooking(slot_index, "noodle")

	row.add_child(cook_noodle_button)



	var take_out_button: Button = Button.new()

	take_out_button.text = TextDB.get_text("UI_STAPLE_LADLE_TAKE_OUT")

	take_out_button.custom_minimum_size = Vector2(64, 28)

	take_out_button.disabled = slot_state != "ready" or held_staple_food_id != "" or not held_disposable_plate

	row.add_child(take_out_button)



	return row



func _get_ladle_state_text(ladle_index: int) -> String:

	var slot_index: int = ladle_index - 1



	if slot_index < 0 or slot_index >= staple_ladle_slots.size():

		return TextDB.get_text("UI_STAPLE_LADLE_EMPTY") % ladle_index



	return get_staple_ladle_text(slot_index)



func request_cart_pot_panel_refresh() -> void:

	panel_controller.request_refresh()





func refresh_cart_pot_panel() -> void:

	panel_controller.refresh()





func close_cart_pot_panel_and_auto_start() -> void:

	if cart_pot_selection.is_empty():

		print("No cart pot selection. Closing panel.")

		close_cart_pot_panel()

		return



	print("Closing cart pot panel and starting a new batch.")

	start_cart_pot_batch_cooking()

	close_cart_pot_panel()



func close_cart_pot_panel() -> void:

	panel_controller.close()





func _on_cart_pot_minus_pressed(item_id: String) -> void:

	var current_amount: int = int(cart_pot_selection.get(item_id, 0))



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

	if not can_add_to_cart_pot_selection(item_id, 1):

		print("Cannot add more to cart pot selection: ", item_id)

		request_cart_pot_panel_refresh()

		return



	cart_pot_selection[item_id] = int(cart_pot_selection.get(item_id, 0)) + 1



	request_cart_pot_panel_refresh()



func _on_cart_pot_max_pressed(item_id: String) -> void:

	var raw_amount: int = int(manager.raw_stock.get(item_id, 0))

	var selected_amount: int = int(cart_pot_selection.get(item_id, 0))

	var available_capacity: int = int(get_cart_pot_available_capacity_for_selection())



	var raw_available: int = raw_amount - selected_amount

	var can_add_amount: int = min(raw_available, available_capacity)



	if can_add_amount <= 0:

		print("No more capacity or stock for cart pot item: ", item_id)

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

	return manager.inventory_system.get_stock_total(manager.cooked_stock)





func get_cart_pot_cooking_capacity_used() -> int:

	var total: int = 0



	for batch in cart_pot_cooking_batches:

		if typeof(batch) != TYPE_DICTIONARY:

			continue



		var items = batch.get("items", {})

		if typeof(items) != TYPE_DICTIONARY:

			continue



		total += manager.inventory_system.get_stock_total(items as Dictionary)



	return total



func get_cart_pot_selection_total() -> int:

	return manager.inventory_system.get_stock_total(cart_pot_selection)





func get_cart_pot_used_capacity() -> int:

	return get_cart_pot_cooked_capacity_used() + get_cart_pot_cooking_capacity_used()





func get_cart_pot_total_capacity_with_selection() -> int:

	return get_cart_pot_used_capacity() + get_cart_pot_selection_total()





func get_cart_pot_available_capacity_for_selection() -> int:

	return max(cart_pot_capacity - get_cart_pot_total_capacity_with_selection(), 0)





func can_add_to_cart_pot_selection(item_id: String, amount: int = 1) -> bool:

	if amount <= 0:

		return false



	var current_selected: int = int(cart_pot_selection.get(item_id, 0))

	var current_raw: int = int(manager.raw_stock.get(item_id, 0))



	if current_selected + amount > current_raw:

		return false



	if get_cart_pot_total_capacity_with_selection() + amount > cart_pot_capacity:

		return false



	return true



func add_to_cart_pot_selection(item_id: String, amount: int = 1) -> void:

	if amount <= 0:

		return



	var actually_added: int = 0



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



	var current_selected: int = int(cart_pot_selection.get(item_id, 0))

	current_selected = max(current_selected - amount, 0)



	if current_selected <= 0:

		cart_pot_selection.erase(item_id)

	else:

		cart_pot_selection[item_id] = current_selected



	refresh_cart_pot_panel()





func max_add_to_cart_pot_selection(item_id: String) -> void:

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

	if cart_pot_selection.is_empty():

		print("No cart pot selection to cook.")

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

		print("Cart pot selection has no cookable ingredients.")

		cart_pot_selection.clear()

		refresh_cart_pot_panel()

		return



	if get_cart_pot_total_capacity_with_selection() > cart_pot_capacity:

		print("Cart pot capacity is full. Cannot start a new batch.")

		refresh_cart_pot_panel()

		return



	for item_id in batch.keys():

		var item_key: String = str(item_id)

		var amount: int = int(batch.get(item_key, 0))

		manager.raw_stock[item_key] = int(manager.raw_stock.get(item_key, 0)) - amount



	cart_pot_cooking_batches.append({

		"items": batch.duplicate(true),

		"time_left": get_effective_cart_pot_batch_duration()

	})

	cart_pot_selection.clear()



	RunSetupData.set_stock_state(manager.raw_stock, manager.cooked_stock, manager.staple_stock)



	print("=== Cart pot batch started ===")

	print("Batch: ", batch)

	print("Active cart pot batches: ", cart_pot_cooking_batches.size())

	print("Raw stock after starting cart pot: ", manager.raw_stock)

	print("Cart pot capacity used: %d/%d" % [

		get_cart_pot_total_capacity_with_selection(),

		cart_pot_capacity

	])



	refresh_cart_pot_panel()



func update_cart_pot(delta: float) -> void:

	if cart_pot_cooking_batches.is_empty():

		return



	var finished_batch_indexes: Array[int] = []



	for i in range(cart_pot_cooking_batches.size()):

		var batch: Dictionary = cart_pot_cooking_batches[i] as Dictionary

		var time_left: float = float(batch.get("time_left", 0.0)) - delta

		batch["time_left"] = time_left

		cart_pot_cooking_batches[i] = batch



		if time_left <= 0.0:

			finished_batch_indexes.append(i)



	for i in range(finished_batch_indexes.size() - 1, -1, -1):

		finish_cart_pot_batch_cooking(int(finished_batch_indexes[i]))



	if panel_controller.is_open():

		refresh_cart_pot_panel()



func finish_cart_pot_batch_cooking(batch_index: int) -> void:

	if batch_index < 0 or batch_index >= cart_pot_cooking_batches.size():

		return



	var batch_data: Dictionary = cart_pot_cooking_batches[batch_index] as Dictionary

	var cooked_batch = batch_data.get("items", {})



	if typeof(cooked_batch) != TYPE_DICTIONARY:

		cart_pot_cooking_batches.remove_at(batch_index)

		return



	var cooked_items: Dictionary = cooked_batch as Dictionary



	for item_id in cooked_items.keys():

		var item_key: String = str(item_id)

		var amount: int = int(cooked_items.get(item_key, 0))



		if amount <= 0:

			continue



		if not manager.cooked_stock.has(item_key):

			manager.cooked_stock[item_key] = 0



		manager.cooked_stock[item_key] = int(manager.cooked_stock.get(item_key, 0)) + amount



	print("=== Cart pot batch finished ===")

	print("Cooked batch: ", cooked_items)



	cart_pot_cooking_batches.remove_at(batch_index)



	RunSetupData.set_stock_state(manager.raw_stock, manager.cooked_stock, manager.staple_stock)



	print("Cooked stock after cart pot: ", manager.cooked_stock)

	print("Cart pot capacity used: ", get_cart_pot_used_capacity(), "/", cart_pot_capacity)



	refresh_cart_pot_panel()

	manager.inventory_system.print_stocks()



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
	held_disposable_plate = false





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



	var changed: bool = false



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

			print(TextDB.get_text("LOG_STAPLE_LADLE_READY") % [i + 1, TextDB.get_item_name(str(slot.get("main_food_id", "")))])

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



		if not manager.order_system.customer_has_main_food(customer):

			continue



		if manager.order_system.get_customer_main_food_stock_id(customer) != main_food_id:

			continue



		if not CustomerOrderState.needs_main_food(customer):

			continue



		return customer



	return null





func has_waiting_main_food_order(main_food_id: String) -> bool:

	return get_unassigned_waiting_main_food_count(main_food_id) > 0





func get_waiting_main_food_count(main_food_id: String) -> int:

	var count: int = 0



	for customer in manager.pending_order_system.get_all():

		if customer == null or not is_instance_valid(customer):

			continue



		if CustomerOrderState.is_served(customer):

			continue



		if CustomerOrderState.needs_emergency_purchase(customer):

			continue



		if not manager.order_system.customer_has_main_food(customer):

			continue



		if manager.order_system.get_customer_main_food_stock_id(customer) != main_food_id:

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

		print(TextDB.get_text("LOG_STAPLE_LADLE_CANNOT_START") % [main_food_id, slot_index])

		return



	var slot: Dictionary = staple_ladle_slots[slot_index] as Dictionary



	slot["state"] = "cooking"

	slot["main_food_id"] = main_food_id

	slot["time_left"] = get_effective_staple_ladle_duration()

	slot["is_ready"] = false

	staple_ladle_slots[slot_index] = slot



	manager.staple_stock[main_food_id] = int(manager.staple_stock.get(main_food_id, 0)) - 1

	RunSetupData.set_stock_state(manager.raw_stock, manager.cooked_stock, manager.staple_stock)



	print(TextDB.get_text("LOG_STAPLE_LADLE_STARTED") % [slot_index + 1, TextDB.get_item_name(main_food_id)])

	print(TextDB.get_text("LOG_STAPLE_LADLE_DURATION") % [float(slot["time_left"])])

	print("Staple stock after putting into ladle: ", manager.staple_stock)



	request_cart_pot_panel_refresh()





func take_ready_staple_from_ladle(slot_index: int) -> void:

	if slot_index < 0 or slot_index >= staple_ladle_slots.size():

		return



	if held_staple_food_id != "":

		print(TextDB.get_text("LOG_STAPLE_HAND_HAS_COOKED_DELIVER_FIRST") % [TextDB.get_item_name(held_staple_food_id)])

		return



	var slot: Dictionary = staple_ladle_slots[slot_index] as Dictionary

	var state: String = str(slot.get("state", "empty"))



	if state != "ready":

		print(TextDB.get_text("LOG_STAPLE_LADLE_NOT_READY_TO_TAKE") % [slot_index + 1])

		return



	var main_food_id: String = str(slot.get("main_food_id", ""))



	if main_food_id == "":

		return

	if not held_disposable_plate:

		print(TextDB.get_text("LOG_PLATE_REQUIRED_FOR_STAPLE"))

		return

	held_disposable_plate = false
	held_staple_food_id = main_food_id



	slot["state"] = "empty"

	slot["main_food_id"] = ""

	slot["time_left"] = 0.0

	staple_ladle_slots[slot_index] = slot



	print(TextDB.get_text("LOG_STAPLE_TAKEN_FROM_LADLE") % [slot_index + 1, TextDB.get_item_name(main_food_id)])



	refresh_cart_pot_panel()





func interact_with_staple_basket(main_food_id: String) -> void:

	if main_food_id == "":

		print(TextDB.get_text("LOG_STAPLE_BASKET_MISSING"))

		return



	if not RunSetupData.is_staple_item(main_food_id):

		print(TextDB.get_text("LOG_STAPLE_ITEM_INVALID") % [main_food_id])

		return



	var display_name: String = TextDB.get_item_name(main_food_id)



	if held_staple_food_id != "":

		print(TextDB.get_text("LOG_STAPLE_HAND_HAS_COOKED_DELIVER_FIRST") % [TextDB.get_item_name(held_staple_food_id)])

		return



	if held_raw_staple_food_id == "":

		var current_stock: int = int(manager.staple_stock.get(main_food_id, 0))



		if current_stock <= 0:

			print(TextDB.get_text("LOG_STAPLE_STOCK_NOT_ENOUGH") % [display_name])

			return



		held_raw_staple_food_id = main_food_id

		print(TextDB.get_text("LOG_STAPLE_PICKED_RAW") % [display_name])

		print(TextDB.get_text("LOG_STAPLE_CURRENT_STOCK") % [str(manager.staple_stock)])

		return



	if held_raw_staple_food_id == main_food_id:

		print(TextDB.get_text("LOG_STAPLE_RETURNED_RAW") % [display_name])

		held_raw_staple_food_id = ""

		return



	print(TextDB.get_text("LOG_STAPLE_HELD_RAW_NEEDS_MATCHING_BASKET") % [TextDB.get_item_name(held_raw_staple_food_id)])


func interact_with_disposable_plate_stack() -> void:

	if held_staple_food_id != "":

		print(TextDB.get_text("LOG_STAPLE_HAND_HAS_COOKED_DELIVER_FIRST") % [TextDB.get_item_name(held_staple_food_id)])

		return

	if held_disposable_plate:

		held_disposable_plate = false
		print(TextDB.get_text("LOG_PLATE_RETURNED"))
		return

	held_disposable_plate = true
	print(TextDB.get_text("LOG_PLATE_PICKED"))





func interact_with_staple_ladle(slot_index: int) -> void:

	if slot_index < 0 or slot_index >= staple_ladle_slots.size():

		print(TextDB.get_text("LOG_STAPLE_LADLE_INDEX_INVALID") % [slot_index])

		return



	var slot: Dictionary = staple_ladle_slots[slot_index] as Dictionary

	var state: String = str(slot.get("state", "empty"))



	if state == "empty":

		if held_raw_staple_food_id == "":

			print(TextDB.get_text("LOG_STAPLE_LADLE_EMPTY_NEEDS_RAW") % [slot_index + 1])

			return



		if held_staple_food_id != "":

			print(TextDB.get_text("LOG_STAPLE_HAND_HAS_COOKED_DELIVER_FIRST") % [TextDB.get_item_name(held_staple_food_id)])

			return



		var main_food_id: String = held_raw_staple_food_id



		if not can_start_staple_ladle_cooking(slot_index, main_food_id):

			print(TextDB.get_text("LOG_STAPLE_CANNOT_PUT_IN_LADLE") % [TextDB.get_item_name(main_food_id), slot_index + 1])

			return



		start_staple_ladle_cooking(slot_index, main_food_id)

		held_raw_staple_food_id = ""

		print(TextDB.get_text("LOG_STAPLE_PUT_IN_LADLE") % [slot_index + 1])

		return



	if state == "cooking":

		var cooking_food_id: String = str(slot.get("main_food_id", ""))

		var time_left: float = float(slot.get("time_left", 0.0))

		print(TextDB.get_text("LOG_STAPLE_LADLE_COOKING_STATUS") % [slot_index + 1, TextDB.get_item_name(cooking_food_id), time_left])

		return



	if state == "ready":

		if held_raw_staple_food_id != "":

			print(TextDB.get_text("LOG_STAPLE_HELD_RAW_BLOCKS_READY") % [TextDB.get_item_name(held_raw_staple_food_id)])

			return



		take_ready_staple_from_ladle(slot_index)

		return



	print(TextDB.get_text("LOG_STAPLE_LADLE_BAD_STATE") % [slot_index + 1, state])





func get_held_raw_staple_text() -> String:

	if held_raw_staple_food_id == "":

		return TextDB.get_text("UI_ITEM_NONE")

	return TextDB.get_item_name(held_raw_staple_food_id)



func get_held_staple_text() -> String:

	if held_staple_food_id == "":

		return TextDB.get_text("UI_ITEM_NONE")



	return TextDB.get_item_name(held_staple_food_id)



func get_staple_ladle_text(slot_index: int) -> String:

	if slot_index < 0 or slot_index >= staple_ladle_slots.size():

		return TextDB.get_text("UI_STAPLE_LADLE_MISSING")



	var slot: Dictionary = staple_ladle_slots[slot_index] as Dictionary

	var state: String = str(slot.get("state", "empty"))

	var main_food_id: String = str(slot.get("main_food_id", ""))

	var main_food_text: String = TextDB.get_text("UI_ITEM_NONE")



	if main_food_id != "":

		main_food_text = TextDB.get_item_name(main_food_id)



	if state == "empty":

		return TextDB.get_text("UI_STAPLE_LADLE_EMPTY") % [slot_index + 1]



	if state == "cooking":

		return TextDB.get_text("UI_STAPLE_LADLE_COOKING") % [

			slot_index + 1,

			main_food_text,

			float(slot.get("time_left", 0.0))

		]



	if state == "ready":

		return TextDB.get_text("UI_STAPLE_LADLE_READY") % [

			slot_index + 1,

			main_food_text

		]



	return TextDB.get_text("UI_STAPLE_LADLE_UNKNOWN") % [slot_index + 1]



func get_cart_ingredients_needed_from_pot(customer: Node) -> Dictionary:

	if customer == null or not is_instance_valid(customer):

		return {}



	var ingredients_to_cook: Dictionary = CustomerOrderState.get_ingredients_to_cook(customer)

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



	var needed_ingredients: Dictionary = get_cart_ingredients_needed_from_pot(customer)



	if CustomerOrderState.needs_emergency_purchase(customer):

		var current_shortage: Dictionary = {}

		if manager.emergency_purchase_system != null:

			current_shortage = manager.emergency_purchase_system.get_customer_shortage(customer)

		if current_shortage.is_empty():

			CustomerOrderState.set_needs_emergency_purchase(customer, false)

		else:

			print(TextDB.get_text("LOG_CUSTOMER_STILL_SHORTAGE_EMERGENCY"))

			return false



	if needed_ingredients.is_empty() and not CustomerOrderState.needs_ingredients(customer):

		return false



	if needed_ingredients.is_empty() and CustomerOrderState.is_ingredients_ready(customer):

		return false



	if needed_ingredients.is_empty():

		CustomerOrderState.mark_ingredients_ready(customer)

		return true



	var ingredients_to_submit: Dictionary = {}
	var remaining_ingredients: Dictionary = {}

	for item_id in needed_ingredients.keys():
		var item_key: String = str(item_id)
		var needed_amount: int = int(needed_ingredients.get(item_key, 0))

		if needed_amount <= 0:
			continue

		var cooked_amount: int = max(int(manager.cooked_stock.get(item_key, 0)), 0)
		var submit_amount: int = int(min(needed_amount, cooked_amount))
		var remaining_amount: int = needed_amount - submit_amount

		if submit_amount > 0:
			ingredients_to_submit[item_key] = submit_amount

		if remaining_amount > 0:
			remaining_ingredients[item_key] = remaining_amount

	if ingredients_to_submit.is_empty():

		print(TextDB.get_text("LOG_CART_COOKED_INGREDIENTS_SHORTAGE") % [str(get_cart_ingredient_shortage_for_customer(customer))])

		return false



	manager.inventory_system.deduct_cooked_stock(ingredients_to_submit)



	CustomerOrderState.set_ingredients_to_cook(customer, remaining_ingredients)

	CustomerOrderState.set_ingredients_deducted_at_checkout(customer, true)



	if remaining_ingredients.is_empty():

		CustomerOrderState.mark_ingredients_ready(customer)

	else:

		CustomerOrderState.set_needs_ingredients(customer, true)

		if customer.has_method("set_cart_ingredients_ready"):

			customer.set_cart_ingredients_ready(false)

		else:

			customer.set("cart_ingredients_ready", false)



	print(TextDB.get_text("LOG_CART_INGREDIENTS_SUBMITTED") % [str(ingredients_to_submit)])

	manager.inventory_system.print_stocks()



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

	var held_food_name: String = TextDB.get_item_name(held_food_id)



	for customer in manager.pending_order_system.get_all():

		if customer == null or not is_instance_valid(customer):

			continue



		if CustomerOrderState.is_served(customer):

			continue



		if not manager.order_system.customer_has_main_food(customer):

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

		print(TextDB.get_text("LOG_HAND_OVER_STAPLE") % [held_food_name])



		return customer



	print(TextDB.get_text("LOG_HAND_STAPLE_NO_MATCHING_CUSTOMER") % [held_food_name])

	return null





func has_busy_cooking() -> bool:

	return has_busy_staple_ladle() or not cart_pot_cooking_batches.is_empty() or has_busy_order_bound_cooker()





func clear_day_end_state() -> Dictionary:

	var discarded: Dictionary = {

		"held_raw": "",

		"held": "",
		"held_plate": false,

		"ladles": []

	}



	if held_raw_staple_food_id != "":

		discarded["held_raw"] = held_raw_staple_food_id

		held_raw_staple_food_id = ""



	if held_staple_food_id != "":

		discarded["held"] = held_staple_food_id

		held_staple_food_id = ""

	if held_disposable_plate:

		discarded["held_plate"] = true
		held_disposable_plate = false



	for i in range(staple_ladle_slots.size()):

		var slot: Dictionary = staple_ladle_slots[i] as Dictionary

		var state: String = str(slot.get("state", "empty"))

		var main_food_id: String = str(slot.get("main_food_id", ""))



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





func discard_held_staple_food() -> Dictionary:

	var discarded: Dictionary = {

		"held_raw": "",

		"held": "",

		"held_plate": false

	}



	if held_raw_staple_food_id != "":

		discarded["held_raw"] = held_raw_staple_food_id

		held_raw_staple_food_id = ""



	if held_staple_food_id != "":

		discarded["held"] = held_staple_food_id

		held_staple_food_id = ""

	if held_disposable_plate:

		discarded["held_plate"] = true
		held_disposable_plate = false



	return discarded





func get_effective_cart_pot_batch_duration() -> float:

	var duration: float = cart_pot_batch_duration



	if manager.day_event_system.has_effect("claw_dance"):

		duration *= 0.8



	return max(duration, 0.2)





func get_effective_staple_ladle_duration() -> float:

	var duration: float = staple_ladle_duration



	if manager.day_event_system.has_effect("claw_dance"):

		duration *= 0.8



	return max(duration, 0.2)
