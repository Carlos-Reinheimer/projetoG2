extends Control

@export var timerDecayRate : float = 0.5
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var timer: Timer = $Timer

var tween: Tween

var fireProgress: float = 0:
	set(value):
		fireProgress = clampf(value, 0, maxPoints)
		updateFireProgress(value)
var maxPoints: float = 0
var progressPoints

func _ready() -> void:
	setUp()
	SignalBus.captureEnemy.connect(onCaptureEnemy)
	SignalBus.extinguishFire.connect(onExinguishFire)
	SignalBus.floorExtinguised.connect(onFloorExtinguised)

func setUp():
	var enemies = get_tree().get_nodes_in_group("Enemy").reduce(func(acc, enemy): return acc + enemy.enemyPoints, 0)
	var fires = get_tree().get_nodes_in_group("Fire").reduce(func(acc, fire): return acc + fire.firePoints, 0)
	maxPoints = enemies + fires
	progress_bar.max_value = maxPoints
	$Label.text = "Pontos máximos: " + str(maxPoints)

func updateFireProgress( value: float ):
	print("recebido o valor " + str(value))
	#if (value < 0 and fireProgress == 0) or (value > 0 and fireProgress == maxPoints):
		#return
	$Label2.text = "Pontos atuais: " + str(fireProgress)
	animateProgressBar(value)

func onCaptureEnemy(points: int):
	print("points recebidos " + str(points))
	fireProgress -= points

func _on_timer_timeout() -> void:
	fireProgress += timerDecayRate

func onExinguishFire(points: int):
	fireProgress -= points

func onFloorExtinguised():
	timer.stop()

func animateProgressBar(novo_valor: float, duracao: float = 0.3) -> void:
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(progress_bar, "value", novo_valor, duracao)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
