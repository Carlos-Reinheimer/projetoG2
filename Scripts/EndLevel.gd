extends Node3D

@onready var player: Player = $Player
@onready var ambulance: Node3D = $ambulance
@onready var dialog_manager: CanvasLayer = $DialogManager
@onready var animation_player: AnimationPlayer = $"Intro CanvasLayer/Intro/AnimationPlayer"
@onready var intro_canvas_layer: CanvasLayer = $"Intro CanvasLayer"

func _ready() -> void:
	SignalBus.endGame.connect(onEndGame)
	player.onStartGame()
	player.enterThrowMode()
	dialog_manager.endGameDialog()

func onEndGame():
	await get_tree().create_timer(2).timeout
	animation_player.play("outro")
	await animation_player.animation_finished
	get_tree().quit()
