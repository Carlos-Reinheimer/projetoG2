extends Node3D

@onready var animation_player: AnimationPlayer = $"Exit Door/AnimationPlayer"
@onready var exit_sign: MeshInstance3D = $"Exit Door/Exit Door/Exit Sign"
@onready var area_light_3d: AreaLight3D = $AreaLight3D
@onready var collision_shape_3d: CollisionShape3D = $"Collision StaticBody/CollisionShape3D"

@export var autoOpenDoor: bool = false
@export var closedMaterial: Material
@export var closedLightColor: Color
@export var openedMaterial: Material
@export var openedLightColor: Color

var unlockDoor : bool = false

func _ready():
	SignalBus.connect("floorExtinguished", onfloorExtinguished)
	
	collision_shape_3d.disabled = false
	exit_sign.material_override = closedMaterial
	area_light_3d.light_color = closedLightColor
	if autoOpenDoor:
		openAnimation()

func openAnimation() -> void:
	collision_shape_3d.disabled = true
	animation_player.play("DoorAction")
	exit_sign.material_override = openedMaterial
	create_tween().tween_property(area_light_3d, "light_color", openedLightColor, .5)

func onfloorExtinguished():
	unlockDoor = true
	openAnimation()

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is not Player or !unlockDoor:
		return

	SignalBus.emit_signal("loadNextFloor")
