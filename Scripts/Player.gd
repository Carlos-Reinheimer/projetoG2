class_name Player
extends CharacterBody3D

const SPEED = 10
const JUMP_VELOCITY = 10
const GRAVITY = Vector3(0, -30, 0)
const TILT_LOWER_LIMIT = deg_to_rad(-30.0)
const TILT_UPPER_LIMIT = deg_to_rad(30.0)
const MOUSE_SENSITIVITY = 0.5

const TARGET_INTENSITY = 15
const INTENSITY_DURATION = 1.5

@onready var camera_3d: Camera3D = $Head/Camera3D
@onready var ray: RayCast3D = $Head/Camera3D/RayCast3D
@onready var ray_cast_3d: RayCast3D = $Head/Camera3D/RayCast3D
@onready var water_splash: GPUParticles3D = $Head/Camera3D/Hose/WaterSplash
@onready var colission_splash: GPUParticles3D = $Head/Camera3D/Hose/WaterSplash/ColissionSplash
@onready var wind_vortex: GPUParticles3D = $Head/Camera3D/Hose/WindVortex

@onready var hoseAnimationPlayer: AnimationPlayer = $Head/Camera3D/Hose/AnimationPlayer
@onready var light_indicator: MeshInstance3D = $"Head/Camera3D/Hose/Light Indicator/Light Indicator"

enum State {
	NORMAL,
	PULLING,
	EXTINGUISH
}

var cur_state := State.NORMAL
var _mouse_input : bool = false
var _mouse_rotation : Vector3
var _rotation_input : float
var _tilt_input : float
var _player_rotation : Vector3
var _camera_rotation : Vector3

var _tween: Tween

var waterLightMat: Material
var windLightMat: Material

var enemyTarget = null

var button_mash = preload("res://Scenes/MiniGame/ButtonMash.tscn")

"""
Player mechanics:
	- Consegue puxar os inimigos
	- Apagar fogo
"""

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	water_splash.emitting = false
	wind_vortex.emitting = false
	colission_splash.emitting = false
	
	waterLightMat = light_indicator.get_active_material(1)
	windLightMat = light_indicator.get_active_material(2)

func drop_target():
	if enemyTarget:
		enemyTarget.stop_pull()
		enemyTarget = null

func EnemyInRange():
	return ray.get_collider() and ray.get_collider().is_in_group("Enemy")

func _physics_process(delta: float) -> void:
	if EnemyInRange():
		enemyTarget = ray.get_collider()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not wind_vortex.emitting:
			wind_vortex.emitting = true
			hoseAnimationPlayer.play("Pull")
			changeEmission(windLightMat, TARGET_INTENSITY)
		if enemyTarget:
			swith_state(State.PULLING)
			enemyTarget.getting_pull(position)
	else:
		if wind_vortex.emitting:
			wind_vortex.emitting = false
			hoseAnimationPlayer.play_backwards("Pull")
			changeEmission(windLightMat, 0)
		swith_state(State.NORMAL)
		drop_target()

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if not water_splash.emitting:
			water_splash.emitting = true
			hoseAnimationPlayer.play("Push")
			changeEmission(waterLightMat, TARGET_INTENSITY)
		if ray.get_collider():
			var colissionPoint = ray.get_collision_point()
			colission_splash.global_position = colissionPoint
			colission_splash.emitting = true
		if ray.get_collider() != null and ray.get_collider().get_parent().has_method("puttingOut"):
			print("To olhando pra " + str(ray.get_collider().name))
			ray.get_collider().get_parent().puttingOut()
	elif water_splash.emitting:
		water_splash.emitting = false
		colission_splash.emitting = false
		hoseAnimationPlayer.play_backwards("Push")
		changeEmission(waterLightMat, 0)
	
	_update_camera(delta)

	if not is_on_floor():
		velocity += GRAVITY * delta

	if Input.is_action_just_pressed("Jump") and is_on_floor() and cur_state != State.PULLING:
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("Left", "Right", "Forward", "Backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	
func _unhandled_input(event):
	_mouse_input = event is InputEventMouseMotion
	if _mouse_input :
		_rotation_input = -event.relative.x * MOUSE_SENSITIVITY
		_tilt_input = -event.relative.y * MOUSE_SENSITIVITY
		
func _update_camera(delta):
	_mouse_rotation.x += _tilt_input * delta
	_mouse_rotation.x = clamp(_mouse_rotation.x, TILT_LOWER_LIMIT, TILT_UPPER_LIMIT)
	_mouse_rotation.y += _rotation_input * delta
	
	_player_rotation = Vector3(0.0,_mouse_rotation.y,0.0)
	_camera_rotation = Vector3(_mouse_rotation.x,0.0,0.0)
	
	camera_3d.transform.basis = Basis.from_euler(_camera_rotation)
	camera_3d.rotation.z = 0.0
	
	global_transform.basis = Basis.from_euler(_player_rotation)
	
	_rotation_input = 0.0
	_tilt_input = 0.0

func swith_state(value : State):
	cur_state = value

func changeEmission(targetMat: Material, targetIntensity: float) -> void:
	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(targetMat, "emission_energy_multiplier", targetIntensity, INTENSITY_DURATION)
