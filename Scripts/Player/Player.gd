class_name Player
extends CharacterBody3D

enum State {
	NORMAL,
	CAPTURING,
	WATTERING,
	PULLING
}

const SPEED = 15
const SPEED_PENALTY = 0.5
const JUMP_VELOCITY = 8
const GRAVITY = Vector3(0, -30, 0)
const TILT_LOWER_LIMIT = deg_to_rad(-30.0)
const TILT_UPPER_LIMIT = deg_to_rad(30.0)
const MAX_SHAKE = 1.5        # deslocamento máximo da câmera
const SHAKE_DECAY = 5.0       # trauma perdido por segundo
const KNOCKBACK_DECAY = 25.0  # quão rápido o empurrão perde força

signal stateChanged(old_state: State, new_state: State)

@onready var camera_3d: Camera3D = $Head/Camera3D
@onready var ray: RayCast3D = $Head/Camera3D/RayCast3D
@onready var ray_cast_3d: RayCast3D = $Head/Camera3D/RayCast3D
@onready var water_splash: GPUParticles3D = $Head/Camera3D/Hose/WaterSplash
@onready var colission_splash: GPUParticles3D = $Head/Camera3D/Hose/WaterSplash/ColissionSplash
@onready var hose: Hose = $Head/Camera3D/Hose
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var mask_animation_player: AnimationPlayer = $"Mask AnimationPlayer"
@onready var capturing_enemy: AudioStreamPlayer = $CapturingEnemy

@export var isAutoPlayable: bool = false
@export var failStun = 1.0
@export var failLockout = 1.0

var isPlayable : bool = false
var _mouse_input : bool = false
var _mouse_rotation : Vector3
var _rotation_input : float
var _tilt_input : float
var _player_rotation : Vector3
var _camera_rotation : Vector3
var stun_left = 0.0
var shake_trauma = 0.0
var knockback = Vector3.ZERO
var currentState = State.NORMAL
var pull_blocked = false
var lockout_left = 0.0

var aimedEnemy: Node = null
var enemyTarget = null

func _ready() -> void:
	SignalBus.connect("endGame", onEndGame)
	SignalBus.connect("restartFloor", restartFloor)
	
	water_splash.emitting = false
	colission_splash.emitting = false
	
	if isAutoPlayable:
		onStartGame()
		putOnMask(true)
	
	_mouse_rotation.y = rotation.y
	_mouse_rotation.x = camera_3d.rotation.x

func _physics_process(delta: float) -> void:
	if not isPlayable:
		return

	_apply_shake(delta)
	lockout_left = maxf(lockout_left - delta, 0.0)
	updateAimHighlight()

	var input_dir = Input.get_vector("Left", "Right", "Forward", "Backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var isMoving = input_dir != Vector2.ZERO
	var isIdle = animation_player.current_animation == "idle"
	if isMoving and isIdle and currentState == State.NORMAL:
		animation_player.play("Moving")
	elif not isMoving:
		animation_player.play("idle")

	var stunned = stun_left > 0.0
	if stunned:
		stun_left -= delta
		dropTarget()
		stopWattering()
		switch_state(State.NORMAL)
		_apply_knockback_move(delta)
		return

	var isPressingLeft := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var isPressingRight := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

	if not isPressingLeft:
		pull_blocked = false
	var canPull := not pull_blocked and lockout_left <= 0.0

	match currentState:
		State.NORMAL:
			if isPressingLeft:
				switch_state(State.PULLING)
				animation_player.play("idle")
			elif isPressingRight:
				startWattering()
		State.PULLING:
			if not isPressingLeft:
				switch_state(State.NORMAL)
			elif canPull and EnemyInRange():
				enemyTarget = ray.get_collider()
				if is_instance_valid(enemyTarget):
					switch_state(State.CAPTURING)
					enemyTarget.gettingPull(self)
			else:
				enemyTarget = null  # da main: não guarda alvo fora do alcance
		State.CAPTURING:
			if not isPressingLeft or not canPull or not is_instance_valid(enemyTarget):
				dropTarget()  # antes do switch_state: dropTarget depende do estado CAPTURING
				switch_state(State.NORMAL)
			else:
				enemyTarget.gettingPull(self)
		State.WATTERING:
			if not isPressingRight:
				stopWattering()
				switch_state(State.NORMAL)

	if currentState == State.CAPTURING:
		faceTarget(delta)
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if currentState == State.WATTERING:
		updateWattering()

	_update_camera(delta)

	if not is_on_floor():
		velocity += GRAVITY * delta

	if Input.is_action_just_pressed("Jump") and is_on_floor() and hose.currentState != Hose.State.PULLING:
		velocity.y = JUMP_VELOCITY

	var speedPenalty = SPEED_PENALTY if isPressingRight or isPressingLeft else 1
	var speed = SPEED * speedPenalty
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	velocity.x += knockback.x
	velocity.z += knockback.z
	move_and_slide()
	knockback = knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)

func _unhandled_input(event):
	_mouse_input = event is InputEventMouseMotion
	if _mouse_input :
		_rotation_input = -event.relative.x * Settings.mouseSensitivity
		_tilt_input = -event.relative.y * Settings.mouseSensitivity

func startWattering() -> void:
	switch_state(State.WATTERING)
	animation_player.play("idle")

func updateWattering() -> void:
	var collider = ray.get_collider()
	if collider and collider.get_parent().has_method("puttingOut"):
		collider.get_parent().puttingOut()

func stopWattering() -> void:
	if water_splash.emitting:
		hose.water_sfx.stop()
		water_splash.emitting = false
		colission_splash.emitting = false

func updateAimHighlight() -> void:
	var col: Object
	if currentState == State.CAPTURING and is_instance_valid(enemyTarget):
		col = enemyTarget
	else:
		col = ray.get_collider()
	var new_aimed: Node = col if (col and col.is_in_group("Enemy")) else null

	if is_instance_valid(aimedEnemy) and aimedEnemy == new_aimed:
		return

	if is_instance_valid(aimedEnemy):
		aimedEnemy.setHighlight(false)

	aimedEnemy = new_aimed
	if aimedEnemy:
		aimedEnemy.setHighlight(true)

func dropTarget():
	if currentState != State.CAPTURING:
		return
	if is_instance_valid(enemyTarget):
		stun(0.2)
		enemyTarget.stopPull()
	enemyTarget = null

func _apply_knockback_move(delta: float) -> void:
	if not is_on_floor():
		velocity += GRAVITY * delta
	velocity.x = knockback.x
	velocity.z = knockback.z
	move_and_slide()
	knockback = knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
		
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

func switch_state(value : State):
	if value == currentState:
		return

	var oldState = currentState
	currentState = value
	stateChanged.emit(oldState, value)

func addShake(amount: float) -> void:
	shake_trauma = minf(shake_trauma + amount, 1.0)

# Cada aperto: shake pequeno que cresce com o progresso
func mashShake(progress: float) -> void:
	addShake(lerpf(0.08, 0.5, progress))

func stun(duration: float = 0.6) -> void:
	stun_left = duration
	shake_trauma = 1.0   # shake final, o mais forte

func pushBack(from: Vector3, strength: float = 14.0) -> void:
	hose.vacuum_sfx.stop()
	#hose.vacuum_of_sfx.play()
	if enemyTarget:
		capturing_enemy.play()
	
	var dir = global_position - from
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = global_transform.basis.z   # sem direção: empurra para trás
	knockback = dir.normalized() * strength

func _apply_shake(delta: float) -> void:
	if shake_trauma > 0.0:
		shake_trauma = maxf(shake_trauma - SHAKE_DECAY * delta, 0.0)
		var s = shake_trauma * shake_trauma * MAX_SHAKE
		camera_3d.h_offset = randf_range(-1.0, 1.0) * s
		camera_3d.v_offset = randf_range(-1.0, 1.0) * s
	else:
		camera_3d.h_offset = 0.0
		camera_3d.v_offset = 0.0

func failedCapture() -> void:
	enemyTarget = null            
	switch_state(State.NORMAL)    
	pull_blocked = true
	lockout_left = failStun + failLockout
	stun(failStun)  

func EnemyInRange():
	return ray.get_collider() and ray.get_collider().is_in_group("Enemy")

func onStartGame() -> void:
	isPlayable = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func putOnMask(skip: bool = false) -> void:
	mask_animation_player.play("putMask") # there's no await.finished?
	if skip:
		mask_animation_player.seek(mask_animation_player.current_animation_length, true)

func onStartLoadNextLevel() -> void:
	isPlayable = false
	
func onFinishLoadNextLevel() -> void:
	isPlayable = true

func onEndGame() -> void:
	await get_tree().create_timer(2).timeout
	isPlayable = false

func restartFloor() -> void:
	await get_tree().create_timer(2).timeout
	isPlayable = true

func faceTarget(delta: float) -> void:
	if not is_instance_valid(enemyTarget):
		return

	var to_enemy: Vector3 = enemyTarget.global_position - global_position
	var flat = Vector2(to_enemy.x, to_enemy.z)
	if flat.length() > 0.01:
		var target_yaw = atan2(-to_enemy.x, -to_enemy.z)
		_mouse_rotation.y = lerp_angle(_mouse_rotation.y, target_yaw, 12.0 * delta)

	var cam_pos = camera_3d.global_position
	var to_enemy_cam: Vector3 = enemyTarget.global_position - cam_pos
	var horizontal = Vector2(to_enemy_cam.x, to_enemy_cam.z).length()
	var target_pitch = atan2(to_enemy_cam.y, horizontal)
	target_pitch = clampf(target_pitch, TILT_LOWER_LIMIT, TILT_UPPER_LIMIT)
	_mouse_rotation.x = lerpf(_mouse_rotation.x, target_pitch, 12.0 * delta)

	camera_3d.transform.basis = Basis.from_euler(Vector3(_mouse_rotation.x, 0.0, 0.0))
	global_transform.basis = Basis.from_euler(Vector3(0.0, _mouse_rotation.y, 0.0))
