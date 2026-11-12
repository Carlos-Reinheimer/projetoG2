extends CharacterBody3D

@export var pull_velocity : float = 0.4
@export var enemyPoints: int = 1
@export var fireRadius := 4.0       
@export var restoreInterval := 5.0   

@onready var button_mash: ButtonMash = $ButtonMash
@onready var navigation: NavigationAgent3D = $NavigationAgent3D
@onready var look_range: Area3D = $LookRange
@onready var animation_player: AnimationPlayer = $ModelSlot/AnimationPlayer

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

var escapeImmunity := 0.0
const ESCAPE_IMMUNITY_TIME := 2.5

const MAX_SPEED := 10.0
const DASH_DURATION := 0.8 
const DASH_BOOST := 12.0  

enum State {
	NORMAL,
	RUNNING,
	GETTING_PULL,
	CAPTURED,
	PHASING
}

func _ready() -> void:
	navigation.link_reached.connect(_on_link_reached)
	outline_material = ShaderMaterial.new()
	outline_material.shader = preload("res://Assets/Shaders/Outline.gdshader")
	# Pega todos os fogos do mapa
	rememberFires()
	await get_tree().physics_frame
	goToRandomFire()

func _physics_process(delta: float) -> void:
	dashLeft = maxf(dashLeft - delta, 0.0)

	if onLink and global_position.distance_to(linkExit) < 1.0:
		_on_link_finished()

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
	escapeImmunity = maxf(escapeImmunity - delta, 0.0)
	if target_position != Vector3.ZERO:
		position = position.move_toward(target_position, delta * pull_velocity)
	updateSpeedRestore(delta)

func setHighlight(on: bool) -> void:
	for m in find_children("*", "MeshInstance3D", true, false):
		#print(m.name, " escala global: ", m.global_transform.basis.get_scale())
		m.material_overlay = outline_material if on else null

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
	if getFires().is_empty():
		return
	animation_player.play("Moving")
	var options := getFires().filter(
		func(f): return f.global_position.distance_to(global_position) > 2.0
	)
	if options.is_empty():
		return
	navigation.set_target_position(options.pick_random().global_position)

func goToMostDistanceFire() -> void:
	animation_player.play("Moving")
	if currentSpeed > 1:
		currentSpeed -= 1
	#print("Velocidade do fogo atualizada para " + str(currentSpeed))
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

func updateSpeedRestore(delta: float) -> void:
	# Longe de chama viva (ou já no máximo): não recupera e zera a contagem
	if currentSpeed >= MAX_SPEED or not isNearRealFire():
		restoreCooldownLeft = restoreInterval
		return
	restoreCooldownLeft -= delta
	if restoreCooldownLeft <= 0.0:
		currentSpeed = min(currentSpeed + 1, MAX_SPEED)
		#print("Velocidade do fogo atualizada para " + str(currentSpeed))
		restoreCooldownLeft = restoreInterval

func gettingPull(player: Player):
	if currentState == State.PHASING or escapeImmunity > 0.0:
		return
	cool_down()
	if currentState == State.GETTING_PULL:
		return
	animation_player.play("Absorb")
	#button_mash.start(ButtonMash.Mode.values().pick_random())
	button_mash.start(ButtonMash.Mode.MASH)
	button_mash.game_finished.connect(_on_button_mash_game_finished)
	currentState = State.GETTING_PULL
	navigation.target_position = global_position
	target_position = player.global_position
	puller = player
	look_at(target_position, Vector3.UP) # melhorar

func stopPull():
	animation_player.play("Moving")
	currentState = State.RUNNING
	button_mash.stop()
	target_position = Vector3.ZERO
	goToMostDistanceFire()

func _on_timer_timeout() -> void:
	queue_free()

func _on_button_mash_game_finished(has_won: bool) -> void:
	print("_on_button_mash_game_finished")
	button_mash.stop()
	if has_won:
		pullInFast()
		return

	SignalBus.emit_signal("captureEnemy", -enemyPoints)
	currentState = State.RUNNING
	target_position = Vector3.ZERO
	goToMostDistanceFire()
	puller.failedCapture()
	puller = null
	dash()
	escapeImmunity = ESCAPE_IMMUNITY_TIME

func dash() -> void:
	dashLeft = DASH_DURATION

func pullInFast() -> void:
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
	SignalBus.emit_signal("captureEnemy", +enemyPoints)
	queue_free()

func _on_look_range_body_entered(body: Node3D) -> void:
	if body is Player and currentState != State.GETTING_PULL:
		currentState = State.RUNNING
		goToMostDistanceFire()

func _on_navigation_agent_3d_navigation_finished() -> void:
	# Se o inimigo está sendo puxado não faz sentido fazer ele andar
	if currentState == State.GETTING_PULL or currentState == State.CAPTURED:
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

func _on_link_started() -> void:
	fadeTo(0.5)
	#print("Passano")
	animation_player.play("Phasing")
	# troca animação, velocidade, desliga colisão, etc.
	pass

func _on_link_finished() -> void:
	onLink = false
	currentLink = null
	fadeTo(1)
	animation_player.play("Moving")
	# volta animação e propriedades ao normal

func fadeTo(value: float, duration: float = 0.3) -> void:
	var tween := create_tween().set_parallel(true)
	for m in find_children("*", "MeshInstance3D", true, false):
		tween.tween_property(m, "transparency", 1.0 - value, duration)

func _on_button_mash_mash_pressed(progress: float) -> void:
	if is_instance_valid(puller):
		puller.mashShake(progress)

func cool_down(duration := 2.0):
	for m in find_children("*", "MeshInstance3D", true, false):
		var mat = m.get_active_material(0)
		if mat is ShaderMaterial:
			var tween := create_tween()
			tween.tween_property(mat, "shader_parameter/cooling", 1.0, duration)
