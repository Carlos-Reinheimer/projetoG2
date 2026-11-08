extends Node3D

@onready var animation_player: AnimationPlayer = $"Exit Door/AnimationPlayer"

@export var autoOpenDoor: bool = false

var unlockDoor : bool = false

func _ready():
	SignalBus.connect("floorExtinguised", onFloorExtinguised)
	if autoOpenDoor:
		openAnimation()

func openAnimation() -> void:
	animation_player.play("DoorAction")

func onFloorExtinguised():
	unlockDoor = true
	openAnimation()

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is not Player or !unlockDoor:
		return

	SignalBus.emit_signal("loadNextFloor")
