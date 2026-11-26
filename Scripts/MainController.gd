class_name MainController
extends Node

enum FloorNumber {ANDAR_10, ANDAR_9, ANDAR_8, ANDAR_7, ANDAR_6, ANDAR_5, ANDAR_4, ANDAR_3, ANDAR_2, ANDAR_1}

@export var floors: Array[PackedScene] = []
@export var startFloor: FloorNumber = FloorNumber.ANDAR_10

@onready var player: Player = $"../Player"
@onready var fade: CanvasLayer = $"../Fade"
@onready var current_floor_label: Label = $"../Current Floor Layer/Current Floor Label"
@onready var current_floor_sfx: AudioStreamPlayer = $"../Current Floor Layer/Current Floor SFX"
@onready var dialog_manager: CanvasLayer = $"../DialogManager"
@onready var floor: Node3D = $"../Floor"

var currentFloor: int = 0
var firesOnFloor: int = 0
var enemiesOnFloor: int = 0
var currentFloorScene: Node3D

func _ready() -> void:
	SignalBus.connect("loadNextFloor", onLoadNextFloor)
	SignalBus.connect("restartFloor", restartFloor)
	SignalBus.connect("captureEnemy", onCaptureEnemy)
	SignalBus.connect("extinguishFire", onExtinguishFire)
	SignalBus.connect("spawnNewFire", onSpawnFire)
	
	Stats.ALL_TIME_ENEMIES_CAPUTRED = 0
	Stats.ALL_TIME_FIRE_EXTINGUISED = 0
	
	current_floor_label.hide()
	if startFloor != 0:
		# technical addaptation to make this work
		var oldFloor = floor
		oldFloor.queue_free()
		await oldFloor.tree_exited
		currentFloor = startFloor
		instantiateLevel()
	else:
		currentFloorScene = $"../Floor"
		setupLevel()

#func _process(delta: float) -> void:
	#print(Engine.get_frames_per_second())

func setupLevel() -> void:
	countFiresOnFloor()
	countEnemiesOnFloor()
	#print("---------")
	#print("currentFloor: " + str(currentFloor))
	#print("enemiesOnFloor: " + str(enemiesOnFloor))
	#print("firesOnFloor: " + str(firesOnFloor))
	
	current_floor_sfx.play()
	
	current_floor_label.text = str((floors.size()) - currentFloor) + "º ANDAR"
	current_floor_label.modulate.a = 0.0
	current_floor_label.show()
	
	var tween = create_tween()
	tween.tween_property(current_floor_label, "modulate:a", 1.0, 0.5)
	tween.tween_interval(1.5)
	tween.tween_property(current_floor_label, "modulate:a", 0.0, 0.4)
	await tween.tween_callback(current_floor_label.hide).finished
	
	SignalBus.emit_signal("setupFloor")

func onLoadNextFloor() -> void:
	dialog_manager.skip()
	player.onStartLoadNextLevel()
	currentFloor += 1
	
	if currentFloor == floors.size():
		Transition.change_scene("res://Scenes/EndLevel.tscn")
		return
	await fade.fade(1.0, 1).finished
	instantiateLevel()
	await fade.fade(0.0, 1).finished
	
	player.onFinishLoadNextLevel()

func restartFloor() -> void:
	await fade.fade(1.0, 1).finished
	instantiateLevel()
	await fade.fade(0.0, 1).finished

func instantiateLevel() -> void:
	if currentFloorScene:
		currentFloorScene.get_parent().remove_child(currentFloorScene)
		currentFloorScene.queue_free()
	
	var newFloor: Node3D = getNewFloor(currentFloor)
	add_child(newFloor)
	currentFloorScene = newFloor
	
	var floorSp = currentFloorScene.get_node("Spawnpoint")
	player.global_position = floorSp.global_position
	
	setupLevel()
	playLevelDialog()
	player.onFinishLoadNextLevel()

func countEnemiesOnFloor() -> void:
	enemiesOnFloor = get_tree().get_nodes_in_group("Enemy").size()

func countFiresOnFloor() -> void:
	firesOnFloor = get_tree().get_nodes_in_group("Fire").size()

func getNewFloor(levelIndex: int) -> Node3D:
	return floors[currentFloor].instantiate()
	
func onCaptureEnemy() -> void:
	enemiesOnFloor -= 1
	Stats.ALL_TIME_ENEMIES_CAPUTRED += 1
	checkFloorCondition()
	
func onExtinguishFire() -> void:
	firesOnFloor -= 1
	Stats.ALL_TIME_FIRE_EXTINGUISED += 1
	checkFloorCondition()

func checkFloorCondition() -> void:
	if enemiesOnFloor == 0 and firesOnFloor == 0:
		if currentFloor == 0:
			dialog_manager.firstLevelComplete()
		else:
			dialog_manager.levelComplete()
		SignalBus.emit_signal("floorExtinguished")

func onSpawnFire(enemyPos: Vector3) -> void:
	firesOnFloor += 1

func playLevelDialog() -> void:
	if currentFloor == 2:
		dialog_manager.greenFireDialog()
