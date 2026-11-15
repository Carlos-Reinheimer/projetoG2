extends Control

@onready var canvas_modulate: CanvasModulate = $CanvasModulate

@export var menuButtons: Array[Button] = []

func _on_start_button_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(canvas_modulate, "color:a", 0, 1.0)
	await tween.finished
	
	for button in menuButtons:
		button.disabled = true
	SignalBus.emit_signal("startGame")

func _on_exit_button_pressed() -> void:
	get_tree().quit()
