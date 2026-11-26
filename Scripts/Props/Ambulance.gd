extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var currentEnemies := 0

func _ready() -> void:
	animation_player.play("open")

func _on_drop_out_enemies_body_entered(body: Node3D) -> void:
	if !body.is_in_group("Enemy"):
		return
	body.remove()
	currentEnemies += 1
	if currentEnemies == Stats.ALL_TIME_ENEMIES_CAPUTRED:
		animation_player.play_backwards("open")
		SignalBus.endGame.emit()
