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
	SignalBus.floorExtinguished.connect(onfloorExtinguished)
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

func sumPoints(groupName: String) -> int:
	var total = 0.0
	for node in get_tree().get_nodes_in_group(groupName):
		if node.has_method("getPoints"):
			total += node.getPoints()
	return total

func setUp():
	var enemies = sumPoints("Enemy")
	var fires = sumPoints("Fire")
	
	maxPoints = enemies + fires
	progress_bar.max_value = maxPoints
	progress_bar.value = 0.0
	
	isRunning = true
	isGameOver = false
	show()

func updatePoints(additionalFirePoints: float) -> void:
	print("additionalFirePoints: " + str(additionalFirePoints))
	progress_bar.max_value += additionalFirePoints

func onCaptureEnemy(points: int):
	fireProgress -= points

func onExinguishFire(points: int):
	fireProgress -= points

func onfloorExtinguished():
	isRunning = false

func onLoadNextFloor() -> void:
	hide()
