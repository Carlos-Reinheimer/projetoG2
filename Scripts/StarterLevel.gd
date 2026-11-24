extends Node3D

@onready var player: Player = $Player
@onready var exit_door: Node3D = $"Exit Door"
@onready var dialog_manager: CanvasLayer = $DialogManager
@onready var animation_player: AnimationPlayer = $"Intro CanvasLayer/Intro/AnimationPlayer"

var canGoToFistLevel := false

func _ready() -> void:
	await dialog_manager.introDialog()
	animation_player.play("intro")
	await animation_player.animation_finished
	SignalBus.connect("startGame", onStartGame)

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is not Player or not canGoToFistLevel:
		return
	
	player.onStartLoadNextLevel()
	Transition.change_scene("res://Scenes/Main.tscn")

func onStartGame() -> void:
	player.onStartGame()
	await dialog_manager.tutorialDialog()
	exit_door.openAnimation()
	canGoToFistLevel = true
