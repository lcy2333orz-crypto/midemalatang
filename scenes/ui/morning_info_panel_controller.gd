class_name MorningInfoPanelController
extends RefCounted

const MorningInfoPanelScene := preload("res://scenes/ui/morning_info_panel.tscn")

var manager: Node = null
var layer: CanvasLayer = null


func bind(game_manager: Node) -> void:
	manager = game_manager


func show(lines: Array[String]) -> void:
	if manager == null or not is_instance_valid(manager):
		return

	close()

	layer = MorningInfoPanelScene.instantiate() as CanvasLayer
	manager.add_child(layer)

	var viewport_size := manager.get_viewport().get_visible_rect().size
	var panel := layer.get_node("MorningInfoPanel") as Panel
	panel.position = Vector2(
		viewport_size.x * 0.5 - 260,
		62
	)

	var label := panel.get_node("MorningInfoLabel") as Label
	label.text = "\n".join(lines)

	var tween := manager.create_tween()
	tween.tween_interval(4.2)
	tween.tween_property(panel, "modulate:a", 0.0, 0.8)

	await manager.get_tree().create_timer(5.1).timeout

	close()


func close() -> void:
	if layer != null and is_instance_valid(layer):
		layer.queue_free()

	layer = null
