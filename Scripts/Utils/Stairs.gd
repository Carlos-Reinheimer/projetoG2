extends Area3D

func _on_body_entered(body: Node3D) -> void:
	if body is not Player and Stats.HAS_EXTINGUISHED_ALL_FIRE_ON_FLOOR:
		return
	
	SignalBus.emit_signal("loadNextFloor")
