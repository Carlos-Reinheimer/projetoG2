extends CharacterBody3D

@export var pull_velocity : float = 0.4
@export var enemyPoints: int = 1

@onready var button_mash: ButtonMash = $ButtonMash

var target_position: Vector3 = Vector3.ZERO

"""
Coisas que o inimigo faz
"""

#func _on_area_3d_body_entered(body: Node3D) -> void:
	#if body is Player:
		#SignalBus.emit_signal("captureEnemy")
		#queue_free()

func _process(delta: float) -> void:
	if target_position != Vector3.ZERO:
		position = position.move_toward(target_position, delta * pull_velocity)

func getting_pull(player_position: Vector3):
	button_mash.start()
	target_position = player_position

func stop_pull():
	button_mash.stop()
	target_position = Vector3.ZERO

func _on_timer_timeout() -> void:
	queue_free()

func _on_button_mash_game_finished(has_won: bool) -> void:
	if has_won:
		SignalBus.emit_signal("captureEnemy", +enemyPoints)
	else:
		SignalBus.emit_signal("captureEnemy", -enemyPoints)
	button_mash.stop()
	queue_free()
