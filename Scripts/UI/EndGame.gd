extends Control

@onready var fire_panel: Panel = $"Fire Panel"
@onready var label: Label = $VBoxContainer/Label
@onready var label_2: Label = $VBoxContainer/Label2

@onready var stats: HBoxContainer = $Stats
@onready var fires_extuinguised_value: Label = $"Stats/Fires Stats/Fires Extuinguised Value"
@onready var ghosts_captured_value: Label = $"Stats/Ghosts Stats/Ghosts Captured Value"

@onready var buttons: HBoxContainer = $Buttons

func _ready() -> void:
	SignalBus.connect("endGame", onEndGame)
	fire_panel.material.set_shader_parameter("progress", 0.0)
	hide()

func onEndGame() -> void:
	setupBeforeShow()
	show()
	
	var tween = create_tween()
	tween.tween_property(fire_panel.material, "shader_parameter/progress", .8, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	
	await create_tween().tween_property(label, "modulate:a", 1.0, 0.5).finished
	await create_tween().tween_property(label_2, "modulate:a", 1.0, 0.5).finished
	
	await create_tween().tween_property(stats, "modulate:a", 1.0, 0.3).finished
	create_tween().tween_method(setFiresExtuinguishedValue, 0, Stats.ALL_TIME_FIRE_EXTINGUISED, 0.8)
	create_tween().tween_method(setGhostsCapturedValue, 0, Stats.ALL_TIME_ENEMIES_CAPUTRED, 0.8)
	create_tween().tween_interval(1.5)
	create_tween().tween_property(buttons, "modulate:a", 1.0, 0.5)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func setFiresExtuinguishedValue(value: int) -> void:
	fires_extuinguised_value.text = str(value)

func setGhostsCapturedValue(value: int) -> void:
	ghosts_captured_value.text = str(value)

func setupBeforeShow() -> void:
	label.modulate.a = 0.0
	label_2.modulate.a = 0.0
	stats.modulate.a = 0.0
	buttons.modulate.a = 0.0

func _on_restart_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()
