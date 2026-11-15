extends Control

const PROGRESS: float = 0.1

@onready var progress_bar: ProgressBar = $ProgressBar

var fireProgress: float = 0
var maxPoints: float = 0
var isRunning: bool = false
var isGameOver: bool = false

func _ready() -> void:
	SignalBus.captureEnemy.connect(onCaptureEnemy)
	SignalBus.extinguishFire.connect(onExinguishFire)
	SignalBus.floorExtinguised.connect(onFloorExtinguised)
	SignalBus.connect("loadNextFloor", onLoadNextFloor)
	hide()

func _process(delta: float) -> void:
	if not isRunning:
		return
	
	fireProgress += PROGRESS * delta
	fireProgress = clampf(fireProgress, 0, maxPoints)
	
	if isGameOver:
		return
	
	progress_bar.value = fireProgress
	if fireProgress == maxPoints:
		isGameOver = true
		SignalBus.emit_signal("endGame")
		
func setUp():
	var enemies = get_tree().get_nodes_in_group("Enemy").reduce(func(acc, enemy): return acc + enemy.enemyPoints, 0)
	var fires = get_tree().get_nodes_in_group("Fire").reduce(func(acc, fire): return acc + fire.firePoints, 0)
	
	maxPoints = enemies + fires
	progress_bar.max_value = maxPoints
	progress_bar.value = 0.0
	
	isRunning = true
	isGameOver = false
	show()

func onCaptureEnemy(points: int):
	fireProgress -= points

func onExinguishFire(points: int):
	fireProgress -= points

func onFloorExtinguised():
	isRunning = false

func onLoadNextFloor() -> void:
	hide()
