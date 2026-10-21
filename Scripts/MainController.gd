extends Node

@export var floors: Array[PackedScene] = []

@onready var player: CharacterBody3D = $"../Player"
@onready var levelUI: Control = $"../LevelUI"
@onready var fade: CanvasLayer = $"../Fade"

var currentFloor: int = 0
var firesOnFloor: int = 0
var enemiesOnFloor: int = 0
var currentFloorScene: Node3D

func _ready() -> void:
	SignalBus.connect("loadNextFloor", onLoadNextFloor)
	SignalBus.connect("captureEnemy", onCaptureEnemy)
	SignalBus.connect("extinguishFire", onExtinguishFire)
	currentFloorScene = $"../Floor"
	
func onLoadNextFloor() -> void:
	currentFloor += 1
	firesOnFloor = 0
	enemiesOnFloor = 0
	
	await fade.fade(1.0, 1).finished
	currentFloorScene.queue_free()
	var newFloor: Node3D = getNewFloor(currentFloor)
	add_child(newFloor)
	currentFloorScene = newFloor
	await fade.fade(0.0, 1).finished

func getNewFloor(levelIndex: int) -> Node3D:
	return floors[currentFloor].instantiate()
	
func onCaptureEnemy(_value: int) -> void:
	enemiesOnFloor -= 1
	Stats.ALL_TIME_ENEMIES_CAPUTRED += 1
	checkFloorCondition()
	
func onExtinguishFire(_value: int) -> void:
	firesOnFloor -= 1
	Stats.ALL_TIME_FIRE_EXTINGUISED += 1
	checkFloorCondition()

func checkFloorCondition() -> void:
	print(" enemigos atuais " + str(enemiesOnFloor) + " fogos atuais " + str(firesOnFloor) )
	if enemiesOnFloor == 0 and firesOnFloor == 0:
		SignalBus.emit_signal("floorExtinguised")
