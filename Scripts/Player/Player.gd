class_name Player
extends CharacterBody3D

const SPEED = 10
const JUMP_VELOCITY = 10
const GRAVITY = Vector3(0, -30, 0)
const TILT_LOWER_LIMIT = deg_to_rad(-30.0)
const TILT_UPPER_LIMIT = deg_to_rad(30.0)
const MOUSE_SENSITIVITY = 0.5
const MAX_SHAKE := 0.12        # deslocamento máximo da câmera
const SHAKE_DECAY := 5.0       # trauma perdido por segundo
const KNOCKBACK_DECAY := 25.0  # quão rápido o empurrão perde força

@onready var camera_3d: Camera3D = $Head/Camera3D
@onready var ray: RayCast3D = $Head/Camera3D/RayCast3D
@onready var ray_cast_3d: RayCast3D = $Head/Camera3D/RayCast3D
@onready var water_splash: GPUParticles3D = $Head/Camera3D/Hose/WaterSplash
@onready var colission_splash: GPUParticles3D = $Head/Camera3D/Hose/WaterSplash/ColissionSplash
@onready var hose: Node3D = $Head/Camera3D/Hose

var _mouse_input : bool = false
var _mouse_rotation : Vector3
var _rotation_input : float
var _tilt_input : float
var _player_rotation : Vector3
var _camera_rotation : Vector3
var stun_left := 0.0
var shake_trauma := 0.0
var knockback := Vector3.ZERO

var aimedEnemy: Node = null
var enemyTarget = null

var button_mash = preload("res://Scenes/MiniGame/ButtonMash.tscn")

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	water_splash.emitting = false
	colission_splash.emitting = false

func updateAimHighlight() -> void:
	var col := ray.get_collider()
	var new_aimed: Node = col if (col and col.is_in_group("Enemy")) else null

	if is_instance_valid(aimedEnemy) and aimedEnemy == new_aimed:
		return

	if is_instance_valid(aimedEnemy):
		aimedEnemy.setHighlight(false)

	aimedEnemy = new_aimed
	if aimedEnemy:
		aimedEnemy.setHighlight(true)

func dropTarget():
	if enemyTarget and cur_state == State.PULLING:
		stun(0.2)
		enemyTarget.stopPull()
		enemyTarget = null

func EnemyInRange():
	return ray.get_collider() and ray.get_collider().is_in_group("Enemy")

func _physics_process(delta: float) -> void:
	updateAimHighlight()

	var stunned := stun_left > 0.0
	if stunned:
		stun_left -= delta
		dropTarget()
		swith_state(State.NORMAL)
		return

	if EnemyInRange():
		enemyTarget = ray.get_collider()
	if enemyTarget:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			swith_state(State.PULLING)
			enemyTarget.gettingPull(self)
	else:
		dropTarget()
		swith_state(State.NORMAL)

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if not water_splash.emitting:
			water_splash.emitting = true
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

	_update_camera(delta)
	_apply_shake(delta)

	if not is_on_floor():
		velocity += GRAVITY * delta

	if Input.is_action_just_pressed("Jump") and is_on_floor() and hose.currentState != Hose.State.PULLING:
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("Left", "Right", "Forward", "Backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	velocity.x += knockback.x
	velocity.z += knockback.z
	move_and_slide()
	velocity.x -= knockback.x
	velocity.z -= knockback.z
	knockback = knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	
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

func addShake(amount: float) -> void:
	shake_trauma = minf(shake_trauma + amount, 1.0)

# Cada aperto: shake pequeno que cresce com o progresso
func mashShake(progress: float) -> void:
	addShake(lerpf(0.08, 0.35, progress))

func stun(duration: float = 0.6) -> void:
	stun_left = duration
	shake_trauma = 1.0   # shake final, o mais forte

func pushBack(from: Vector3, strength: float = 14.0) -> void:
	var dir := global_position - from
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = global_transform.basis.z   # sem direção: empurra para trás
	knockback = dir.normalized() * strength

func _apply_shake(delta: float) -> void:
	if shake_trauma > 0.0:
		shake_trauma = maxf(shake_trauma - SHAKE_DECAY * delta, 0.0)
		var s := shake_trauma * shake_trauma * MAX_SHAKE
		camera_3d.h_offset = randf_range(-1.0, 1.0) * s
		camera_3d.v_offset = randf_range(-1.0, 1.0) * s
	else:
		camera_3d.h_offset = 0.0
		camera_3d.v_offset = 0.0
