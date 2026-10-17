extends Control

@export var timerDecayRate : float = 1

var currentPoints: float = 0:
	set(value):
		currentPoints = value
		$ProgressBar.value = value
var maxPoints: float = 0

func _ready() -> void:
	SignalBus.captureEnemy.connect(onCaptureEnemy)
	SignalBus.extinguishFire.connect(onExinguishFire)

func setUp(value: float):
	maxPoints = value
	$ProgressBar.max_value = maxPoints
	currentPoints = maxPoints / 2 # Começar pela metade só pq sim
	$ProgressBar.value = currentPoints

func onCaptureEnemy(points: int):
	print("points recebidos " + str(points))
	currentPoints += points

func _on_timer_timeout() -> void:
	currentPoints -= timerDecayRate

func onExinguishFire(points: int):
	currentPoints += points
