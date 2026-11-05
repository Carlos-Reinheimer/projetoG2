extends Control

@export var timerDecayRate : float = 10

@onready var fire_panel: Panel = $"../Endgame Control/Fire Panel"
@onready var progress_bar: ProgressBar = $ProgressBar

var currentPoints: float = 0:
	set(value):
		currentPoints = value
		$ProgressBar.value = value
var maxPoints: float = 0
var tween: Tween

func _ready() -> void:
	SignalBus.captureEnemy.connect(onCaptureEnemy)
	SignalBus.extinguishFire.connect(onExinguishFire)
	
	fire_panel.material.set_shader_parameter("progress", 0)
	maxPoints = progress_bar.max_value
	setUp()

func setUp():
	currentPoints = maxPoints / 2 # Começar pela metade só pq sim
	updateUI(currentPoints)

func updateUI(target: float, duration: float = 1) -> void:
	if tween and tween.is_running():
		tween.kill()

	tween = create_tween()
	print(target)
	tween.tween_property(progress_bar, "value", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func onCaptureEnemy(points: int):
	print("points recebidos " + str(points))
	currentPoints += points
	updateUI(currentPoints)

func _on_timer_timeout() -> void:
	currentPoints += timerDecayRate
	updateUI(currentPoints)

func onExinguishFire(points: int):
	currentPoints -= points
	updateUI(currentPoints)
