class_name Hose
extends Node

enum State {
	NORMAL,
	PULLING,
	EXTINGUISH
}

const TARGET_INTENSITY = 15
const INTENSITY_DURATION = 1.5

@onready var player: Player = $"../../.."
@onready var ray: RayCast3D = $"../RayCast3D"

@onready var hose_animation_player: AnimationPlayer = $AnimationPlayer
@onready var hose_mesh: MeshInstance3D = $Hose

@onready var water_splash: GPUParticles3D = $WaterSplash
@onready var colission_splash: GPUParticles3D = $WaterSplash/ColissionSplash
@onready var wind_vortex: GPUParticles3D = $WindVortex

@export var idleIndicatorColor: Color
@export var extinguishIndicatorColor: Color
@export var pullIndicatorColor: Color

# Public
var currentState := State.NORMAL

# Private
var _emissionTween: Tween
var _lightMat: StandardMaterial3D
var _enemyTarget = null

func _ready() -> void:
	water_splash.emitting = false
	wind_vortex.emitting = false
	colission_splash.emitting = false
	_lightMat = hose_mesh.get_active_material(1)
	
func _process(delta: float) -> void:
	processHose(delta)
	processEnemy(delta)

func processHose(delta: float) -> void:
	var isPressingLeft = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var isPressingRight = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if isPressingLeft and not isPressingRight:
		if not wind_vortex.emitting:
			wind_vortex.emitting = true
			updateHoseFeedback("Pull", false, pullIndicatorColor, TARGET_INTENSITY)
	elif wind_vortex.emitting:
		wind_vortex.emitting = false
		updateHoseFeedback("Pull", true, idleIndicatorColor, 0)

	if isPressingRight and not isPressingLeft:
		if not water_splash.emitting:
			water_splash.emitting = true
			updateHoseFeedback("Push", false, extinguishIndicatorColor, TARGET_INTENSITY)
	elif water_splash.emitting:
		water_splash.emitting = false
		colission_splash.emitting = false
		updateHoseFeedback("Push", true, idleIndicatorColor, 0)

func processEnemy(delta: float) -> void:
	if isEnemyInRange():
		_enemyTarget = ray.get_collider()

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _enemyTarget:
		switchState(State.PULLING)
		_enemyTarget.getting_pull(player.position)
	else:
		switchState(State.NORMAL)
		dropTarget()

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if ray.get_collider():
			var colissionPoint = ray.get_collision_point()
			colission_splash.global_position = colissionPoint
			colission_splash.emitting = true
		if ray.get_collider() != null and ray.get_collider().get_parent().has_method("puttingOut"):
			ray.get_collider().get_parent().puttingOut()

func updateHoseFeedback(animation: String, backwards: bool, targetColor: Color, targetIntensity: float) -> void:
	if not backwards:
		hose_animation_player.play(animation)
	else:
		hose_animation_player.play_backwards(animation)
	changeEmission(targetColor, targetIntensity)

func changeEmission(targetColor: Color, targetIntensity: float) -> void:
	if _emissionTween and _emissionTween.is_running():
		_emissionTween.kill()

	_lightMat.albedo_color = targetColor
	_lightMat.emission = targetColor
	_emissionTween = create_tween()
	_emissionTween.tween_property(_lightMat, "emission_energy_multiplier", targetIntensity, INTENSITY_DURATION)

func isEnemyInRange() -> bool:
	return ray.get_collider() and ray.get_collider().is_in_group("Enemy")

func dropTarget():
	if not _enemyTarget:
		return

	_enemyTarget.stop_pull()
	_enemyTarget = null

func switchState(value : State):
	currentState = value
