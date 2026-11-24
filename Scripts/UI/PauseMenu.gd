extends CanvasLayer

const DEFAULT_LAYER = 0
const PAUSED_LAYER = 999

@onready var player: Player = $"../Player"
@onready var pause_canvas_layer: CanvasLayer = $"."

@onready var mouse_sensitivity_slider: HSlider = $"PauseMenu/Options Buttons/VBoxContainer/Gameplay Panel/MarginContainer/Master/Mouse Sensitivity Slider"

func _ready() -> void:
	mouse_sensitivity_slider.value = Settings.mouseSensitivity
	mouse_sensitivity_slider.value_changed.connect(onMouseSensitivityChanged)

func _process(delta: float) -> void:
	pressEsc()

func onMouseSensitivityChanged(value: float) -> void:
	Settings.mouseSensitivity = value

func resume():
	get_viewport().gui_release_focus()
	pause_canvas_layer.layer = DEFAULT_LAYER
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false
	$PauseMenu/AnimationPlayer.play_backwards("blur")
	
func pause():
	pause_canvas_layer.layer = PAUSED_LAYER
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	$PauseMenu/AnimationPlayer.play("blur")
	
func pressEsc():
	if Input.is_action_just_pressed("Escape") and not get_tree().paused and player.isPlayable:
		pause()
	elif Input.is_action_just_pressed("Escape") and get_tree().paused:
		resume()

func _on_resume_button_pressed() -> void:
	resume()

func _on_options_button_pressed() -> void:
	$PauseMenu/AnimationPlayer.play("options")

func _on_restart_current_level_button_pressed() -> void:
	resume()
	SignalBus.emit_signal("restartFloor")

func _on_home_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/StarterLevel.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_return_button_pressed() -> void:
	$PauseMenu/AnimationPlayer.play_backwards("options")
