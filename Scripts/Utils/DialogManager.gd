extends CanvasLayer

@onready var character_dialog: RichTextLabel = $Panel/CharacterDialog
@onready var character_name: Label = $Panel/CharacterName
@onready var panel: Panel = $Panel
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

var _last_char_count := 0
var dialog_is_playing := false 
var current_tween: Tween
var skip_all := false

# Dialogos
var introDialogText := [""]

var characterName := "Tutor Rial"

#var dialogss: Array[String] = [
	#"Olá! Eu sou [b]muito[/b] legal.",
	#"Cuidado com o [color=red]perigo[/color]!",
	#"Que [wave amp=30 freq=5]tremedeira[/wave]...",
	#"[shake rate=20 level=10]AAAAH![/shake]",
	#"[rainbow freq=0.5 sat=0.8]Colorido![/rainbow]",
	#"[i]sussurrando...[/i]",
#]

func _ready() -> void:
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2.ZERO
	panel.modulate.a = 0.0
	SignalBus.floorExtinguished.connect(onfloorExtinguished)

func onfloorExtinguished():
	await get_tree().create_timer(2).timeout

func firstLevelComplete():
	await get_tree().create_timer(1).timeout
	showDialog("Tutor Rial", ["Andar limpo, soldado", "Pode seguir para o próximo andar", "E cuidado"])

func levelComplete():
	await get_tree().create_timer(1).timeout
	showDialog("Tutor Rial", ["Andar limpo, soldado"])

func introDialog():
	await get_tree().create_timer(0.5).timeout
	showDialog("Tutor Rial", ["Bem vindo mano"])

func showDialog(character: String, dialogs: Array[String]):
	if dialog_is_playing:
		return
	dialog_is_playing = true
	popIn()
	character_name.text = character
	for dialog in dialogs:
		if skip_all:
			break
		character_dialog.text = dialog
		character_dialog.visible_ratio = 0
		_last_char_count = 0

		var duration = character_dialog.get_total_character_count() * 0.05

		current_tween = create_tween()
		current_tween.tween_property(character_dialog, "visible_ratio", 1.0, duration)
		current_tween.step_finished.connect(func(_i): pass) # opcional
		await current_tween.finished

		await get_tree().create_timer(1).timeout
	skip_all = false
	popOut()
	dialog_is_playing = false

func _process(_delta):
	var current = character_dialog.visible_characters
	if current > _last_char_count:
		var new_char = character_dialog.text[current - 1] if current <= character_dialog.text.length() else " "
		if new_char != " " and new_char != "." and new_char != "," and new_char != "\n":
			_play_voice()
		_last_char_count = current

func _play_voice():
	audio_stream_player.pitch_scale = randf_range(0.9, 1.1)
	audio_stream_player.play()

func popIn() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	await tween.finished

func popOut() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "scale", Vector2.ZERO, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, 0.2)
	await tween.finished
