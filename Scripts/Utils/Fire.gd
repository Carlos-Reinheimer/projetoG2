extends Node3D

var health : int = 15 # Trocar por uma progress bar
var firePoints : float = 2

func _on_timer_timeout() -> void:
	queue_free()

func puttingOut() -> void:
	health -= 1
	checkDeath()

func checkDeath() -> void:
	if health <= 0:
		SignalBus.emit_signal("extinguishFire", firePoints)
		queue_free()
