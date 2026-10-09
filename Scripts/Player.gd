class_name Player
extends CharacterBody3D

const SPEED = 10
const JUMP_VELOCITY = 10
const GRAVITY = Vector3(0, -30, 0)
const TILT_LOWER_LIMIT = deg_to_rad(-90.0)
const TILT_UPPER_LIMIT = deg_to_rad(90.0)
const MOUSE_SENSITIVITY = 0.5

@onready var camera_3d: Camera3D = $Head/Camera3D
@onready var ray_cast_3d: RayCast3D = $Head/Camera3D/RayCast3D
@onready var timer: Timer = $Timer
@onready var progress_bar: ProgressBar = $"../Control/ProgressBar"

var _mouse_input : bool = false
var _mouse_rotation : Vector3
var _rotation_input : float
var _tilt_input : float
var _player_rotation : Vector3
var _camera_rotation : Vector3

var enemy_target = null

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func drop_target():
	if enemy_target:
		print("larguei de mao")
		enemy_target.stop_pull()
		enemy_target = null

func _physics_process(delta: float) -> void:
	if ray_cast_3d.get_collider() and ray_cast_3d.get_collider().is_in_group("Enemy"):
		enemy_target = ray_cast_3d.get_collider()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and enemy_target:
		if timer.time_left == 0:
			timer.start()
		enemy_target.getting_pull(position)
	else:
		drop_target()
		
	_update_camera(delta)
	
	if enemy_target:
		if Input.is_action_just_pressed("Jump"):
			timer.stop()
		return
		
	if not is_on_floor():
		velocity += GRAVITY * delta

	if Input.is_action_just_pressed("Jump") and is_on_floor():
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
