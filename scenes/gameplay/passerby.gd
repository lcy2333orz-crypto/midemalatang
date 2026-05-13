extends CharacterBody2D

@export var move_speed: float = 95.0
@export var target_position: Vector2 = Vector2.ZERO


func setup(start_position: Vector2, exit_position: Vector2, speed_multiplier: float = 1.0) -> void:
	global_position = start_position
	target_position = exit_position
	move_speed *= max(speed_multiplier, 0.1)


func _physics_process(_delta: float) -> void:
	var to_target: Vector2 = target_position - global_position

	if to_target.length() <= 6.0:
		queue_free()
		return

	velocity = to_target.normalized() * move_speed
	move_and_slide()


func blocks_cart_cleanup() -> bool:
	return false
