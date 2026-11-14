extends Control

const PROGRESS: float = 0.1

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var endgame_panel: Control = $"../Endgame Panel"

var fireProgress: float = 0
var maxPoints: float = 0
var isRunning: bool = false

func _ready() -> void:
	SignalBus.captureEnemy.connect(onCaptureEnemy)
	SignalBus.extinguishFire.connect(onExinguishFire)
	SignalBus.floorExtinguised.connect(onFloorExtinguised)

func _process(delta: float) -> void:
	if not isRunning:
		return
	
	fireProgress += PROGRESS * delta
	fireProgress = clampf(fireProgress, 0, maxPoints)
	
	if fireProgress > maxPoints:
		return
	
	progress_bar.value = fireProgress
	if fireProgress == maxPoints:
		SignalBus.emit_signal("endGame")
		displayEndgamePanel()
		
func setUp():
	var enemies = get_tree().get_nodes_in_group("Enemy").reduce(func(acc, enemy): return acc + enemy.enemyPoints, 0)
	var fires = get_tree().get_nodes_in_group("Fire").reduce(func(acc, fire): return acc + fire.firePoints, 0)
	maxPoints = enemies + fires
	progress_bar.max_value = maxPoints
	progress_bar.value = 0.0
	isRunning = true

func displayEndgamePanel() -> void:
	print("test")
	var tween = create_tween()
	tween.tween_property(endgame_panel.material, "shader_parameter/progress", .8, 5.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished

func onCaptureEnemy(points: int):
	fireProgress -= points

func onExinguishFire(points: int):
	fireProgress -= points

func onFloorExtinguised():
	isRunning = false
