extends Node3D

@onready var animation_player: AnimationPlayer = $"Exit Door/AnimationPlayer"

var unlockDoor : bool = false

func _ready():
	SignalBus.connect("floorExtinguised", onFloorExtinguised)

func onFloorExtinguised():
	unlockDoor = true
	animation_player.play("DoorAction")

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is not Player or !unlockDoor:
		return

	SignalBus.emit_signal("loadNextFloor")
