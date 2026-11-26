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
var tutorialDialogText : Array[String] = ["[i]Atenção, cadete[/i]", "Isso não é um treinamento", "Esse é seu primeiro incêndio de [color=red]burnout[/color] de verdade", "Mas não se preocupe, estou aqui para te relembrar do seu treinamento",
"Primeiramente o básico, apagar o fogo, mas não qualquer [wave amp=30 freq=5]foguinho normal[/wave]", "Temos fogos [color=purple]roxos[/color], [color=blue]azuis[/color] e [color=green]verdes[/color], cada um mais demorado de apagar do que o outro",
"Mas não se preocupa, apenas os apague com sua mangueira [Pressionando o botão direito do mouse]", "Agora, os [wave amp=30 freq=5][b]fantasmas[/b][/wave]... esses são outra história", "Ao invés de apagá-los, devemos [i]capturá-los[/i] [Pressionando botão esquerdo do mouse]",
"Porém cuidado, [i]conseguir[/i] capturá-los é mais difícil do que parece", "E lembre-se, [b]sempre limpe um andar antes de seguir para o próximo[/b]", "Boa sorte, cadete"]

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
	await _wait(1)
	showDialog("Tutor Rial", ["Andar limpo, soldado", "Pode seguir para o próximo andar", "E cuidado"])

func levelComplete():
	await _wait(1)
	showDialog("Tutor Rial", ["Andar limpo, soldado"])

func tutorialDialog():
	await _wait(0.5)
	await showDialog("Tutor Rial", tutorialDialogText)

func introDialog():
	await _wait(0.5)
	await showDialog("Tutor Rial", ["Na sociedade que vivemos hoje, um fenômeno extraordinário acontece", "Aqueles que vão muito além dos seus limites...", "Acabam virando... [wave amp=30 freq=5]outra coisa[/wave]", "E é para isso que nós existimos, para resgatá-los"], true)

func greenFireDialog():
	await _wait(2)
	await showDialog("Tutor Rial", ["Cuidado", "Nesse andar parece que identificamos alguns fogos [wave amp=30 freq=5]especias[/wave]", "Como saber se é especial?", "Pela cor, deve ter algum fogo [color=green]verde[/color] por ai", "São complicadinhos, parece que nunca vão apagar", "Mas tenha paciência, eles apenas [b]levam um tempinho a mais[/b]"])

func endGameDialog():
	await _wait(0.5)
	await showDialog("Tutor Rial", ["Bom trabalho, cadete. Sabia que podia contar com você", "Agora manda esses maluquinhos para a ambulância", "Se esqueceu?", "É no mesmo [b]botão que usa para capturar[/b]", "Ela troca automaticamente quando fica cheia", "Vamos lá, pode mandar eles embora!"])

func _wait(seconds: float) -> void:
	var t := get_tree().create_timer(seconds)
	while t.time_left > 0.0 and not skip_all:
		await get_tree().process_frame

func skip():
	skip_all = true

func _unhandled_input(event: InputEvent) -> void:
	if dialog_is_playing and event.is_action_pressed("SkipDialog"):
		skip_all = true
		get_viewport().set_input_as_handled()

func showDialog(character: String, dialogs: Array[String], text_only := false):
	if dialog_is_playing:
		return
	dialog_is_playing = true

	# Só texto: painel invisível, nome escondido, sem animação de "pop"
	panel.self_modulate.a = 0.0 if text_only else 1.0
	character_name.visible = not text_only
	if text_only:
		panel.scale = Vector2.ONE
		panel.modulate.a = 1.0
	else:
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
		while current_tween.is_running() and not skip_all:
			await get_tree().process_frame
		current_tween.kill()

		await _wait(1.0)

	skip_all = false
	if text_only:
		await _fade_out_text()
	else:
		popOut()
	dialog_is_playing = false

func _fade_out_text() -> void:
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	await tween.finished
	panel.scale = Vector2.ZERO
	panel.self_modulate.a = 1.0  # volta ao normal pros próximos diálogos

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
