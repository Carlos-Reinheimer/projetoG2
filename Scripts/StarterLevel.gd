extends Node3D

@onready var player: Player = $Player
@onready var exit_door: Node3D = $"Exit Door"

func _ready() -> void:
	SignalBus.connect("startGame", onStartGame)

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is not Player:
		return
	
	player.onStartLoadNextLevel()
	Transition.change_scene("res://Scenes/Main.tscn")

func onStartGame() -> void:
	print("test")
	player.onStartGame()
	exit_door.openAnimation()
