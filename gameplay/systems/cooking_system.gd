class_name CookingSystem
extends RefCounted

var manager = null


func bind(game_manager: Node) -> void:
	manager = game_manager


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	if manager == null or not is_instance_valid(manager):
		warnings.append("CookingSystem is not bound to a valid GameManager.")
		return warnings

	if typeof(manager.cooker_slots) != TYPE_ARRAY:
		warnings.append("CookingSystem: cooker_slots is not an Array.")

	if typeof(manager.staple_ladle_slots) != TYPE_ARRAY:
		warnings.append("CookingSystem: staple_ladle_slots is not an Array.")

	if typeof(manager.cart_pot_selection) != TYPE_DICTIONARY:
		warnings.append("CookingSystem: cart_pot_selection is not a Dictionary.")

	return warnings


func open_cart_pot_panel() -> void:
	manager.open_cart_pot_panel()


func interact_with_staple_basket(main_food_id: String) -> void:
	manager.interact_with_staple_basket(main_food_id)


func interact_with_staple_ladle(slot_index: int) -> void:
	manager.interact_with_staple_ladle(slot_index)


# TODO: Move cart-pot and staple-ladle state machines out of GameManager.
# This system should own cooking timers and expose delivery-ready updates.
