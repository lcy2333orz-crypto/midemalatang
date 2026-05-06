class_name StationLayoutSystem
extends RefCounted

const ATTACHED_STATION_OFFSETS: Dictionary = {
	"counter": {
		"gift_box": Vector2(52, -12)
	},
	"cooker_1": {
		"staple_ladle_1": Vector2(-34, 2),
		"staple_ladle_2": Vector2(34, 2)
	},
	"storage": {
		"glass_noodle_basket": Vector2(-42, -54),
		"noodle_basket": Vector2(42, -54)
	}
}

var manager = null


func bind(game_manager: Node) -> void:
	manager = game_manager


func debug_validate() -> Array[String]:
	var warnings: Array[String] = []

	if manager == null or not is_instance_valid(manager):
		warnings.append("StationLayoutSystem is not bound to a valid GameManager.")
		return warnings

	if manager.slot_a == null or manager.slot_b == null or manager.slot_c == null:
		warnings.append("StationLayoutSystem: one or more primary layout slots are missing.")

	if manager.counter_node == null:
		warnings.append("StationLayoutSystem: Counter station node is missing.")

	if manager.delivery_node == null:
		warnings.append("StationLayoutSystem: DeliveryPoint station node is missing.")

	if manager.storage_node == null:
		warnings.append("StationLayoutSystem: StorageArea station node is missing.")

	if manager.cooker_1_node == null:
		warnings.append("StationLayoutSystem: primary Cooker station node is missing.")

	if manager.gift_box_node == null:
		warnings.append("StationLayoutSystem: GiftBox / tip jar station node is missing.")

	if manager.glass_noodle_basket_node == null or manager.noodle_basket_node == null:
		warnings.append("StationLayoutSystem: one or more staple basket station nodes are missing.")

	if manager.staple_ladle_1_node == null or manager.staple_ladle_2_node == null:
		warnings.append("StationLayoutSystem: one or more staple ladle station nodes are missing.")

	return warnings


func apply_station_layout_from_run_setup() -> void:
	var layout: Dictionary = RunSetupData.station_layout

	place_station_by_slot(manager.counter_node, str(layout.get("counter", "")))
	place_station_by_slot(manager.delivery_node, str(layout.get("delivery", "")))
	place_station_by_slot(manager.storage_node, str(layout.get("storage", "")))
	place_station_by_slot(manager.cooker_1_node, str(layout.get("cooker_1", "")))
	place_station_by_slot(manager.emergency_shop_node, str(layout.get("emergency_shop", "")))
	place_attached_stations()

	if manager.cooker_2_node != null:
		if manager.has_second_cooker:
			manager.cooker_2_node.visible = true
			place_station_by_slot(manager.cooker_2_node, str(layout.get("cooker_2", "")))
		else:
			manager.cooker_2_node.visible = false


func place_attached_stations() -> void:
	place_attached_station(manager.gift_box_node, manager.counter_node, "counter", "gift_box")
	place_attached_station(manager.staple_ladle_1_node, manager.cooker_1_node, "cooker_1", "staple_ladle_1")
	place_attached_station(manager.staple_ladle_2_node, manager.cooker_1_node, "cooker_1", "staple_ladle_2")
	place_attached_station(manager.glass_noodle_basket_node, manager.storage_node, "storage", "glass_noodle_basket")
	place_attached_station(manager.noodle_basket_node, manager.storage_node, "storage", "noodle_basket")


func place_attached_station(
	station_node: Node2D,
	anchor_node: Node2D,
	anchor_key: String,
	attached_key: String
) -> void:
	if station_node == null or anchor_node == null:
		return

	var anchor_offsets: Dictionary = ATTACHED_STATION_OFFSETS.get(anchor_key, {})
	var offset: Vector2 = anchor_offsets.get(attached_key, Vector2.ZERO)
	station_node.global_position = anchor_node.global_position + offset
	print("Placed attached station ", station_node.name, " near ", anchor_node.name, " -> ", station_node.global_position)


func place_station_by_slot(station_node: Node2D, slot_id: String) -> void:
	if station_node == null:
		return

	var slot_marker: Marker2D = get_slot_marker_by_id(slot_id)
	if slot_marker == null:
		print("No valid slot found for station: ", station_node.name, " slot_id: ", slot_id)
		return

	station_node.global_position = slot_marker.global_position
	print("Placed station ", station_node.name, " at ", slot_id, " -> ", slot_marker.global_position)


func get_slot_marker_by_id(slot_id: String) -> Marker2D:
	match slot_id:
		"slot_a":
			return manager.slot_a
		"slot_b":
			return manager.slot_b
		"slot_c":
			return manager.slot_c
		"slot_d":
			return manager.slot_d
		"slot_e":
			return manager.slot_e
		"slot_f":
			return manager.slot_f
		_:
			return null
