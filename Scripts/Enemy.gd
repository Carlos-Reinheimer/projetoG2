extends CharacterBody3D

@export var pull_velocity : int = 2

@onready var timer: Timer = $Timer

var target_position: Vector3 = Vector3.ZERO

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is Player:
		queue_free()

func _process(delta: float) -> void:
	if target_position != Vector3.ZERO:
		position = position.move_toward(target_position, delta * pull_velocity)

func getting_pull(player_position: Vector3):
	target_position = player_position

func stop_pull():
	target_position = Vector3.ZERO

func _on_timer_timeout() -> void:
	queue_free()
