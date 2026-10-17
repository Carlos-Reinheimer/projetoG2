extends Area3D

var unlockDoor : bool = false

func _ready():
	SignalBus.floorExtinguised.connect(onFloorExtinguised)

func _on_body_entered(body: Node3D) -> void:
	if body is not Player or !unlockDoor:
		return

	SignalBus.emit_signal("loadNextFloor")

func onFloorExtinguised():
	unlockDoor = true
