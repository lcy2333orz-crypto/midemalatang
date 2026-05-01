class_name ReputationSystem
extends RefCounted

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


# TODO: Move served/failed customer accounting, special-customer echo recording,
# and reputation deltas out of GameManager.
