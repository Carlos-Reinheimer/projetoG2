extends Node3D

@onready var player: Player = $Player
@onready var exit_door: Node3D = $"Exit Door"
@onready var dialog_manager: CanvasLayer = $DialogManager

func _ready() -> void:
	SignalBus.connect("startGame", onStartGame)

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is not Player:
		return
	
	player.onStartLoadNextLevel()
	Transition.change_scene("res://Scenes/Main.tscn")

func onStartGame() -> void:
	dialog_manager.introDialog()
	player.onStartGame()
	exit_door.openAnimation()
