extends Node

@export var floors: Array[PackedScene] = []

@onready var player: CharacterBody3D = $"../Player"
@onready var fade: CanvasLayer = $"../Fade"
@onready var fire_progress_ui: Control = $"../Fire Progress UI"
@onready var current_floor_label: Label = $"../Current Floor Layer/Current Floor Label"

var currentFloor: int = 0
var firesOnFloor: int = 0
var enemiesOnFloor: int = 0
var currentFloorScene: Node3D

func _ready() -> void:
	SignalBus.connect("loadNextFloor", onLoadNextFloor)
	SignalBus.connect("captureEnemy", onCaptureEnemy)
	SignalBus.connect("extinguishFire", onExtinguishFire)
	
	Stats.ALL_TIME_ENEMIES_CAPUTRED = 0
	Stats.ALL_TIME_FIRE_EXTINGUISED = 0
	
	currentFloorScene = $"../Floor"
	current_floor_label.hide()
	
	setupLevel()

func setupLevel() -> void:
	countFiresOnFloor()
	countEnemiesOnFloor()
	
	current_floor_label.text = str(currentFloor + 1) + "º ANDAR"
	current_floor_label.modulate.a = 0.0
	current_floor_label.show()
	
	var tween = create_tween()
	tween.tween_property(current_floor_label, "modulate:a", 1.0, 0.5)
	tween.tween_interval(1.5)
	tween.tween_property(current_floor_label, "modulate:a", 0.0, 0.4)
	await tween.tween_callback(current_floor_label.hide).finished
	
	fire_progress_ui.setUp()

func onLoadNextFloor() -> void:
	player.onStartLoadNextLevel()
	currentFloor += 1
	
	await fade.fade(1.0, 1).finished
	currentFloorScene.queue_free()
	
	var newFloor: Node3D = getNewFloor(currentFloor)
	add_child(newFloor)
	currentFloorScene = newFloor
	
	var floorSp = currentFloorScene.get_node("Spawnpoint")
	player.global_position = floorSp.global_position
	
	await fade.fade(0.0, 1).finished
	setupLevel()
	player.onFinishLoadNextLevel()

func countEnemiesOnFloor() -> void:
	enemiesOnFloor = get_tree().get_nodes_in_group("Enemy").size()

func countFiresOnFloor() -> void:
	firesOnFloor = get_tree().get_nodes_in_group("Fire").size()

func getNewFloor(levelIndex: int) -> Node3D:
	return floors[currentFloor].instantiate()
	
func onCaptureEnemy(value: int) -> void:
	if value < 0:
		return
	enemiesOnFloor -= 1
	Stats.ALL_TIME_ENEMIES_CAPUTRED += 1
	checkFloorCondition()
	
func onExtinguishFire(_value: int) -> void:
	firesOnFloor -= 1
	Stats.ALL_TIME_FIRE_EXTINGUISED += 1
	checkFloorCondition()

func checkFloorCondition() -> void:
	if enemiesOnFloor == 0 and firesOnFloor == 0:
		SignalBus.emit_signal("floorExtinguised")
