class_name ButtonMash extends Control

@export var mash_time = 0.4
@export var press_boost = 5
@export var decay_rate = 8
@export var max_progress = 100

@onready var timer: Timer = $Timer
@onready var progress_bar: ProgressBar = $ProgressBar

signal game_finished(has_won: bool) # True: ganhou - False: perdeu

# Supostamente com isso, toda vez que o btnCount mudar, tbm altera o progress bar
var btnCount: float = 0.0:
	set(value):
		btnCount = clampf(value, 0.0, max_progress)
		if is_node_ready() and progress_bar:
			progress_bar.value = btnCount

func _ready() -> void:
	visible = false
	timer.wait_time = mash_time
	progress_bar.max_value = max_progress

func start():
	if visible:
		return
	visible = true
	timer.start()

func stop():
	visible = false
	timer.stop()
	btnCount = 0

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		btnCount += press_boost
		if progress_bar.max_value <= btnCount:
			emit_signal("game_finished", true)

func _on_timer_timeout() -> void:
	print("cabo timer")
	btnCount -= decay_rate
	if btnCount <= 0:
			emit_signal("game_finished", false)
