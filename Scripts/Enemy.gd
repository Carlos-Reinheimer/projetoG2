extends CharacterBody3D

@export var pull_velocity : float = 0.4
@export var enemyPoints: int = 1
@export var fireRadius := 4.0       
@export var restoreInterval := 5.0   

@onready var button_mash: ButtonMash = $ButtonMash
@onready var perception_timer: Timer = $PerceptionTimer
@onready var navigation: NavigationAgent3D = $NavigationAgent3D
@onready var look_range: Area3D = $LookRange

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

const MAX_SPEED := 10.0

enum State {
	NORMAL,
	RUNNING,
	GETTING_PULL,
	CAPTURED
}


"""
TODO: 
	- Inimigo fugir do player
	- Velocidade conforme Instensidade
	- Aumentar intensidade perto de chamas
	- Quando as chames se extinguirem, remover da lógica
	- Se se extinguir enquanto o inimigo estiver lá, o que faz? 
"""

func _ready() -> void:
	navigation.link_reached.connect(_on_link_reached)
	outline_material = ShaderMaterial.new()
	outline_material.shader = preload("res://Assets/Shaders/Outline.gdshader")
	# Pega todos os fogos do mapa
	rememberFires()
	await get_tree().physics_frame
	goToRandomFire()

func setHighlight(on: bool) -> void:
	for m in find_children("*", "MeshInstance3D", true, false):
		print(m.name, " escala global: ", m.global_transform.basis.get_scale())
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
	var options := getFires().filter(
		func(f): return f.global_position.distance_to(global_position) > 2.0
	)
	if options.is_empty():
		return
	navigation.set_target_position(options.pick_random().global_position)

func goToMostDistanceFire() -> void:
	if currentSpeed > 1:
		currentSpeed -= 1
	print("Velocidade do fogo atualizada para " + str(currentSpeed))
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

func _physics_process(_delta: float) -> void:
	if onLink and global_position.distance_to(linkExit) < 1.0:
		_on_link_finished()

	if navigation.is_navigation_finished():
		return

	var next_pos := navigation.get_next_path_position()
	var direction := (next_pos - global_position)
	direction.y = 0.0
	direction = direction.normalized()

	velocity.x = direction.x * currentSpeed
	velocity.z = direction.z * currentSpeed

	# Vira o inimigo na direção do movimento
	if direction.length() > 0.01:
		look_at(global_position + direction, Vector3.UP)

	move_and_slide()

func _process(delta: float) -> void:
	if target_position != Vector3.ZERO:
		position = position.move_toward(target_position, delta * pull_velocity)
	updateSpeedRestore(delta)

func updateSpeedRestore(delta: float) -> void:
	# Longe de chama viva (ou já no máximo): não recupera e zera a contagem
	if currentSpeed >= MAX_SPEED or not isNearRealFire():
		restoreCooldownLeft = restoreInterval
		return
	restoreCooldownLeft -= delta
	if restoreCooldownLeft <= 0.0:
		currentSpeed = min(currentSpeed + 1, MAX_SPEED)
		print("Velocidade do fogo atualizada para " + str(currentSpeed))
		restoreCooldownLeft = restoreInterval

func gettingPull(player: Player):
	button_mash.start()
	currentState = State.GETTING_PULL
	navigation.target_position = global_position
	target_position = player.global_position
	puller = player

func stopPull():
	currentState = State.RUNNING
	button_mash.stop()
	target_position = Vector3.ZERO
	goToMostDistanceFire()

func _on_timer_timeout() -> void:
	queue_free()

func _on_button_mash_game_finished(has_won: bool) -> void:
	if has_won:
		pullInFast()
	else:
		SignalBus.emit_signal("captureEnemy", -enemyPoints)
		currentState = State.RUNNING
		goToMostDistanceFire()
		puller.dropTarget()
		puller = null
	button_mash.stop()

func pullInFast() -> void:
	currentState = State.CAPTURED
	target_position = Vector3.ZERO   # desliga o puxão lento do _process
	set_physics_process(false)       # para a navegação

	var start := global_position
	var tween := create_tween()
	tween.tween_method(
		func(t: float): global_position = start.lerp(puller.hose.global_position, t),
		0.0, 1.0, 0.25
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "scale", Vector3.ONE * 0.2, 0.25)

	#await tween.finished
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
	print("Passano")
	# troca animação, velocidade, desliga colisão, etc.
	pass

func _on_link_finished() -> void:
	onLink = false
	currentLink = null
	fadeTo(1)
	# volta animação e propriedades ao normal

func fadeTo(value: float, duration: float = 0.3) -> void:
	var tween := create_tween().set_parallel(true)
	for m in find_children("polygon*", "MeshInstance3D", true, false):
		tween.tween_property(m, "transparency", 1.0 - value, duration)

func _on_button_mash_mash_pressed(progress: float) -> void:
	if is_instance_valid(puller):
		puller.mashShake(progress)
