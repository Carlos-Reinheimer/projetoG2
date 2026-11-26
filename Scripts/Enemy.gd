class_name Enemy
extends CharacterBody3D

enum CAPTURE_MODE {APPROACH, ESCAPE, WET}

const SPAWN_FIRE_CHANCE = 0.25
const DELAY_BETWEEN_FIRE_SPAWN = 2.0
const DELAY_DECAY = 0.1
const WET_RATE = 0.02
const WET_DURATION = 3.0

@export var captureMode: CAPTURE_MODE = CAPTURE_MODE.APPROACH
@export var escapeSpeed = 5.0
@export var drySpeed = 0.15

@export var pull_velocity : float = 0.4
@export var fireRadius := 4.0       
@export var restoreInterval := 5.0   
@export var canSpawnFire: bool = false

@onready var button_mash: ButtonMash = $ButtonMash
@onready var navigation: NavigationAgent3D = $NavigationAgent3D
@onready var look_range: Area3D = $LookRange
@onready var animation_player: AnimationPlayer = $ModelSlot/AnimationPlayer
@onready var flames: GPUParticles3D = $Flames
@onready var flame_sfx: AudioStreamPlayer3D = $"Flames/Flame SFX"

# SFX
@onready var sfx: AudioStreamPlayer3D = $SFX
const GHOST_CRYING_SOUND_EFFECT = preload("uid://b6fvmi7lfk3xa")
const SAD_GHOST = preload("uid://77tpotvyvwr2")
const PICKING = preload("uid://rllc240mvamg")
const GHOST_BUTTON_MASH = preload("uid://c4cmqidshxoak")
const LAUGH_SOUND_EFFECT = preload("uid://cveon05m54iab")

var outline_material: ShaderMaterial
var fire_memory: Array[Vector3] = []
var target_position: Vector3 = Vector3.ZERO
var currentState := State.NORMAL
var currentSpeed := 5.0
var restoreCooldownLeft := 0.0
var puller = null
var onLink := false
var linkExit := Vector3.ZERO
var currentLink: Node = null
var dashLeft := 0.0
var heat_tween: Tween
var fade_tween: Tween
var spawnFireDelay: float = 0.0
var isImmune: bool = false
var howWet: float = 0.0
var wetDuration: float = 0.0

static var active_mash_enemy: Node = null

@export var fleeDistance := 12.0
@export var fleeTime := 4.0

var fleeId := 0

var escapeImmunity := 0.0
const ESCAPE_IMMUNITY_TIME := 2.5
const DECAY_IMMUNITY = 0.5

@export var buttonMashMode := ButtonMash.Mode.MASH
@export var buttonMashDifficulty := ButtonMash.Difficulty.NORMAL

const MAX_SPEED := 20.0
const MIN_SPEED := 5.0
const DASH_DURATION := 0.8 
const DASH_BOOST := 12.0  

var spawned_thrown := false
var thrown_time := 0.0
const THROW_GRAVITY := Vector3(0, -30, 0)

enum State {
	NORMAL,
	RUNNING,
	GETTING_PULL,
	CAPTURED,
	PHASING,
	THROWN
}

func _ready() -> void:
	if spawned_thrown:
		navigation.link_reached.connect(_on_link_reached)
		_setUpOutlineShader()
		return
	await NavigationServer3D.map_changed
	await get_tree().physics_frame
	navigation.link_reached.connect(_on_link_reached)
	_setUpOutlineShader()
	rememberFires()
	goToRandomFire()

func _setUpOutlineShader() -> void:
	outline_material = ShaderMaterial.new()
	outline_material.shader = preload("res://Assets/Shaders/Outline.gdshader")

func _physics_process(delta: float) -> void:
	if currentState == State.THROWN:
		_thrown_physics(delta)
		return

	if onLink:
		var flat_exit := Vector2(linkExit.x, linkExit.z)
		var flat_pos := Vector2(global_position.x, global_position.z)
		if flat_pos.distance_to(flat_exit) < 1.0:
			_on_link_finished()

	if captureMode == CAPTURE_MODE.ESCAPE and puller != null:
		var away = global_position - puller.global_position
		away.y = 0.0
		velocity = -away.normalized() * escapeSpeed
		move_and_slide()
		return

	if navigation.is_navigation_finished():
		return

	var next_pos := navigation.get_next_path_position()
	var direction := (next_pos - global_position)
	direction.y = 0.0
	direction = direction.normalized()

	var speed := currentSpeed + DASH_BOOST * (dashLeft / DASH_DURATION)

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	# Vira o inimigo na direção do movimento
	if direction.length() > 0.01:
		look_at(global_position + direction, Vector3.UP)

	move_and_slide()

func _process(delta: float) -> void:
	if isImmune and escapeImmunity > 0.0:
		escapeImmunity -= DECAY_IMMUNITY * delta
	elif isImmune and escapeImmunity <= 0.0:
		setTransparency(1, .1)
		isImmune = false
	if spawnFireDelay > 0.0:
		spawnFireDelay -= DELAY_DECAY * delta
	
	if wetDuration >= 0.0:
		wetDuration -= delta
	elif wetDuration <= 0.0 and howWet >= 1.0:
		howWet = 0.0
		flames.emitting = true
		flames.amount_ratio = 1
		flames.scale = Vector3.ONE
		heatUp(0.5)

	if puller == null:
		updateSpeedRestore(delta)
		return
	
	if captureMode == CAPTURE_MODE.APPROACH and target_position != Vector3.ZERO:
		position = position.move_toward(target_position, delta * pull_velocity)
	updateSpeedRestore(delta)

func setHighlight(on: bool) -> void:
	if isImmune:
		return
	if not canBeCaptured():
		return
	
	for m in find_children("*", "MeshInstance3D", true, false):
		m.material_overlay = outline_material if on else null

func setTransparency(value: float, duration: float) -> void:
	if fade_tween:
		fade_tween.kill()
	fade_tween = create_tween().set_parallel(true)
	for m in find_children("*", "MeshInstance3D", true, false):
		fade_tween.tween_property(m, "transparency", 1.0 - value, duration)

func rememberFires() -> void:
	for f in getFires():
		var known := fire_memory.any(
			func(p: Vector3): return p.distance_to(f.global_position) < 1.0
		)
		if not known:
			fire_memory.append(f.global_position)

func getFires() -> Array[Node]:
	return get_tree().get_nodes_in_group("Fire")

func getCandidateSpots() -> Array[Vector3]:
	rememberFires()
	var spots: Array[Vector3] = []
	var live := getFires()
	if live.is_empty():
		spots.assign(fire_memory)
	else:
		for f in live:
			spots.append(f.global_position)
	return spots

func isNearRealFire() -> bool:
	for f in getFires():
		if global_position.distance_to(f.global_position) <= fireRadius:
			return true
	return false

func goToRandomFire() -> void:
	var options := getFires().filter(
		func(f): return f.global_position.distance_to(global_position) > 2.0
	)
	if options.is_empty():
		await get_tree().create_timer(1.0).timeout
		if currentState == State.NORMAL and not is_queued_for_deletion():
			goToRandomFire()
		return
	animation_player.play("Moving")
	var target: Vector3 = options.pick_random().global_position
	target += Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	navigation.target_position = NavigationServer3D.map_get_closest_point(
		navigation.get_navigation_map(), target)

func goToMostDistanceFire() -> void:
	animation_player.play("Moving")
	if currentSpeed > 1:
		updateHeatFromSpeed()
		if currentSpeed > MIN_SPEED:
			currentSpeed -= 1
	if getFires().is_empty():
		return
	var fires = getFires()
	var farthest_position: Vector3 = fires[0].global_position
	var max_distance: float = 0.0

	for fire in fires:
		var distance := global_position.distance_to(fire.global_position)
		if distance > max_distance:
			max_distance = distance
			farthest_position = fire.global_position

	navigation.set_target_position(farthest_position)

func startRunning(threat_pos: Vector3) -> void:
	switchState(State.RUNNING)
	animation_player.play("Moving")
	if currentSpeed > 1:
		updateHeatFromSpeed()
		if currentSpeed > MIN_SPEED:
			currentSpeed -= 1

	var map := navigation.get_navigation_map()
	var away := global_position - threat_pos
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU)
	away = away.normalized()

	var best := global_position
	var best_score := -INF
	for i in 12:
		var dir := away.rotated(Vector3.UP, randf_range(-PI * 0.6, PI * 0.6))
		var raw := global_position + dir * randf_range(fleeDistance * 0.8, fleeDistance * 1.3)
		var p := NavigationServer3D.map_get_closest_point(map, raw)
		var score := p.distance_to(threat_pos) + p.distance_to(global_position) * 0.5
		if score > best_score:
			best_score = score
			best = p
	navigation.target_position = best

	fleeId += 1
	var my_id := fleeId
	await get_tree().create_timer(fleeTime).timeout
	if my_id != fleeId or currentState != State.RUNNING:
		return
	switchState(State.NORMAL)
	goToRandomFire()

func updateSpeedRestore(delta: float) -> void:
	# Longe de chama viva (ou já no máximo): não recupera e zera a contagem
	if currentSpeed >= MAX_SPEED or not isNearRealFire():
		restoreCooldownLeft = restoreInterval
		return
	restoreCooldownLeft -= delta
	if restoreCooldownLeft <= 0.0:
		currentSpeed = min(currentSpeed + 1, MAX_SPEED)
		heatUp(restoreInterval)
		restoreCooldownLeft = restoreInterval

func gettingPull(player: Player):
	if currentState == State.THROWN:
		return
	if currentState == State.CAPTURED or is_queued_for_deletion():
		return
	if currentState == State.PHASING or escapeImmunity > 0.0:
		return
	if currentState == State.GETTING_PULL:
		return
	if _isMashBusy():
		return
	active_mash_enemy = self
	coolDown()
	animation_player.play("Absorb")
	playSound(GHOST_BUTTON_MASH)
	button_mash.start(buttonMashMode, buttonMashDifficulty)
	if not button_mash.game_finished.is_connected(_on_button_mash_game_finished):
		button_mash.game_finished.connect(_on_button_mash_game_finished)
	currentState = State.GETTING_PULL
	navigation.target_position = global_position
	target_position = player.global_position
	puller = player
	look_at(target_position, Vector3.UP) # melhorar

func stopPull():
	if currentState != State.GETTING_PULL:
		return
	_releaseMash()
	var threat = puller.global_position if is_instance_valid(puller) else global_position
	playSound(LAUGH_SOUND_EFFECT, false)
	button_mash.stop()
	target_position = Vector3.ZERO
	puller = null
	startRunning(threat)

func _on_timer_timeout() -> void:
	queue_free()

func _on_button_mash_game_finished(has_won: bool) -> void:
	sfx.stop()
	button_mash.stop()
	if has_won:
		pullInFast()
		return

	_releaseMash()
	playSound(LAUGH_SOUND_EFFECT, false)
	startRunning(puller.global_position)
	target_position = Vector3.ZERO
	puller.failedCapture()
	puller.pushBack(global_position)
	puller = null
	dash()
	escapeImmunity = ESCAPE_IMMUNITY_TIME
	isImmune = true
	setTransparency(0.3, ESCAPE_IMMUNITY_TIME)

func dash() -> void:
	dashLeft = DASH_DURATION

func pullInFast() -> void:
	playSound(PICKING)
	currentState = State.CAPTURED
	target_position = Vector3.ZERO
	set_physics_process(false)

	var start := global_position
	var tween := create_tween().set_parallel(true)
	tween.tween_method(
		func(t: float): global_position = start.lerp(puller.hose.global_position, t),
		0.0, 1.0, 0.25
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector3.ONE * 0.2, 0.25)

	await tween.finished

	puller.pushBack(start)
	puller.stun(0.6)
	remove_from_group("Enemy")
	SignalBus.emit_signal("captureEnemy")
	CapturedEnemies.add(scene_file_path)
	_releaseMash()
	queue_free()

func _on_look_range_body_entered(body: Node3D) -> void:
	if body is Player and currentState == State.NORMAL:
		dash()
		startRunning(body.global_position)

func _on_navigation_agent_3d_navigation_finished() -> void:
	# Se o inimigo está sendo puxado não faz sentido fazer ele andar
	if currentState == State.GETTING_PULL or currentState == State.CAPTURED or currentState == State.THROWN:
		return
	if currentState == State.RUNNING:
		animation_player.play("Idle")
		return
	animation_player.play("Idle")
	currentState = State.NORMAL
	var wait_time := 10.0 if isNearRealFire() else 2.0
	await get_tree().create_timer(wait_time).timeout
	if currentState != State.NORMAL:
		return  # foi assustado ou puxado durante a espera
	goToRandomFire()

func _on_link_reached(details: Dictionary) -> void:
	onLink = true
	linkExit = details.link_exit_position
	currentLink = details.get("owner")  # o NavigationLink3D, se existir
	_on_link_started()
	trySpawnFire()

func _on_link_started() -> void:
	switchState(State.PHASING)
	animation_player.play("Phasing")
	playSound(GHOST_CRYING_SOUND_EFFECT)
	fadeTo(0.5)
	trySpawnFire()

func _on_link_finished() -> void:
	onLink = false
	currentLink = null
	fadeTo(1.0)
	if currentState == State.PHASING:
		switchState(State.NORMAL)
	animation_player.play("Moving")

func fadeTo(value: float, duration: float = 0.3) -> void:
	setTransparency(value, duration)

func _on_button_mash_mash_pressed(progress: float) -> void:
	if is_instance_valid(puller):
		puller.mashShake(progress)

func setCooling(target: float, duration: float) -> void:
	if heat_tween:
		heat_tween.kill()
	heat_tween = create_tween().set_parallel(true)
	for m in find_children("*", "MeshInstance3D", true, false):
		if m.get_surface_override_material(0) == null:
			var mat = m.get_active_material(0)
			if mat is ShaderMaterial:
				m.set_surface_override_material(0, mat.duplicate())
		var own = m.get_surface_override_material(0)
		if own:
			heat_tween.tween_property(own, "shader_parameter/cooling", target, duration)

func coolDown(duration := 2.0) -> void:
	setCooling(1.0, duration)

func heatUp(duration := 2.0) -> void:
	setCooling(0.0, duration)

func updateHeatFromSpeed() -> void:
	var heat := currentSpeed / MAX_SPEED         
	setCooling(1.0 - heat, 0.5)                

func switchState(newState: State) -> void:
	if currentState == State.PHASING and newState != State.PHASING:
		fadeTo(1.0, 0.15)
	currentState = newState

func playSound(soundName, wait := true):
	sfx.stream = soundName
	if sfx.playing and wait:
		await sfx.finished
	sfx.play()

func trySpawnFire() -> void:
	if not canSpawnFire or spawnFireDelay > 0.0:
		return
	
	spawnFireDelay = DELAY_BETWEEN_FIRE_SPAWN
	var random = RandomNumberGenerator.new().randf()
	if random <= SPAWN_FIRE_CHANCE:
		SignalBus.emit_signal("spawnNewFire", global_position)

func _isMashBusy() -> bool:
	return is_instance_valid(active_mash_enemy) and active_mash_enemy != self

func _releaseMash() -> void:
	if active_mash_enemy == self:
		active_mash_enemy = null

func _exit_tree() -> void:
	_releaseMash() 

func launch(vel: Vector3) -> void:
	playSound(LAUGH_SOUND_EFFECT)
	switchState(State.THROWN)
	velocity = vel
	thrown_time = 0.0
	navigation.target_position = global_position
	animation_player.play("Idle")

func _thrown_physics(delta: float) -> void:
	thrown_time += delta
	velocity += THROW_GRAVITY * delta
	move_and_slide()
	if thrown_time > 0.1 and is_on_floor():
		velocity = Vector3.ZERO
		animation_player.play("Idle")
		set_physics_process(false) 

func remove():
	await sfx.finished
	queue_free()

func gettingWet() -> void:
	if captureMode != CAPTURE_MODE.WET:
		return

	howWet += WET_RATE
	howWet = clampf(howWet, 0.0, 1.0)
	flames.amount_ratio = remap(howWet, 0.0, 1.0, 1.0, 0.5)
	flames.scale = Vector3.ONE * remap(howWet, 0.0, 1.0, 1.0, 0.3)
	if howWet >= 1:
		wetDuration = WET_DURATION
		flames.emitting = false
		flame_sfx.play()
		coolDown(0.5)

func canBeCaptured() -> bool:
	return captureMode != CAPTURE_MODE.WET or howWet >= 1.0
