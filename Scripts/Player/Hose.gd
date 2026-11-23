class_name Hose
extends Node

enum State {
	NORMAL,
	PULLING,
	EXTINGUISH
}

const TARGET_INTENSITY = 15
const INTENSITY_DURATION = 1.5
const PULL_STATES = [Player.State.PULLING, Player.State.CAPTURING]

@onready var player: Player = $"../../.."
@onready var ray: RayCast3D = $"../RayCast3D"

@onready var hose_animation_player: AnimationPlayer = $AnimationPlayer
@onready var hose_mesh: MeshInstance3D = $Hose

@onready var water_splash: GPUParticles3D = $WaterSplash
@onready var colission_splash: GPUParticles3D = $WaterSplash/ColissionSplash
@onready var wind_vortex: GPUParticles3D = $WindVortex
@onready var cone: MeshInstance3D = $WindVortex/Cone

#SFX
@onready var water_sfx: AudioStreamPlayer = $"../../../WaterSFX"
@onready var vacuum_sfx: AudioStreamPlayer = $"../../../VacuumSFX"
@onready var vacuum_of_sfx: AudioStreamPlayer = $"../../../VacuumOfSFX"
@onready var capturing_enemy: AudioStreamPlayer = $"../../../CapturingEnemy"

@export var idleIndicatorColor: Color
@export var extinguishIndicatorColor: Color
@export var pullIndicatorColor: Color

# Public
var currentState = State.NORMAL

# Private
var _emissionTween: Tween
var _lightMat: StandardMaterial3D
var _enemyTarget = null

func _ready() -> void:
	water_splash.emitting = false
	wind_vortex.emitting = false
	colission_splash.emitting = false
	_lightMat = hose_mesh.get_active_material(1)
	
	player.stateChanged.connect(onPlayerStateChanged)
	
func _process(delta: float) -> void:
	if player.currentState == Player.State.WATTERING and ray.get_collider():
		colission_splash.global_position = ray.get_collision_point()
		colission_splash.emitting = true
	else:
		colission_splash.emitting = false

func onPlayerStateChanged(oldState: Player.State, newState: Player.State) -> void:
	var wasPulling = oldState in PULL_STATES
	var isPulling = newState in PULL_STATES

	if isPulling and not wasPulling:
		startPullVisuals()
	elif wasPulling and not isPulling:
		stopPullVisuals()

	if newState == Player.State.WATTERING:
		startWaterVisuals()
	elif oldState == Player.State.WATTERING:
		stopWaterVisuals()
		
func startPullVisuals() -> void:
	vacuum_sfx.play()
	wind_vortex.emitting = true
	cone.visible = true
	updateHoseFeedback("Pull", false, pullIndicatorColor, TARGET_INTENSITY)

func stopPullVisuals() -> void:
	vacuum_sfx.stop()
	if not capturing_enemy.playing:
		vacuum_of_sfx.play()
	wind_vortex.emitting = false
	cone.visible = false
	updateHoseFeedback("Pull", true, idleIndicatorColor, 0)

func startWaterVisuals() -> void:
	water_sfx.play()
	water_splash.emitting = true
	updateHoseFeedback("Push", false, extinguishIndicatorColor, TARGET_INTENSITY)

func stopWaterVisuals() -> void:
	water_sfx.stop()
	water_splash.emitting = false
	colission_splash.emitting = false
	updateHoseFeedback("Push", true, idleIndicatorColor, 0)

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

	_enemyTarget.stopPull()
	_enemyTarget = null

func switchState(value : State):
	currentState = value

func stopVacuumSound() -> void:
	var s = vacuum_sfx.stream as AudioStreamWAV
	if s and vacuum_sfx.playing:
		var pos = vacuum_sfx.get_playback_position()
		s.loop_mode = AudioStreamWAV.LOOP_DISABLED
		vacuum_sfx.play(pos)
