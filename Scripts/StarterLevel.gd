extends Node3D

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is not Player:
		return
	
	Transition.change_scene("res://Scenes/Main.tscn")
