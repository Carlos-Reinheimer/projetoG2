class_name ButtonMash extends Control

enum Mode { MASH, ALTERNATE, SEQUENCE }

@export var mode: Mode = Mode.MASH

@export_group("Mash / Alternate")
@export var mash_time = 0.4
@export var press_boost = 5
@export var decay_rate = 8
@export var max_progress = 100
## Ações (Input Map) que contam no modo MASH
@export var mash_actions: Array[StringName] = [&"Jump"]
## Ações dos dois lados no modo ALTERNATE
@export var left_actions: Array[StringName] = [&"Left"]
@export var right_actions: Array[StringName] = [&"Right"]

@export_group("Sequence")
@export var sequence_pool: Array[StringName] = [&"Forward", &"Backward", &"Left", &"Right"]
@export var sequence_length := 5
@export var sequence_time := 4.0
## true: errar volta ao início da sequência / false: errar só é ignorado
@export var wrong_press_resets := true

@export_group("Prompts (texturas)")
## Pasta + prefixo + nome da tecla + sufixo + ".png"
## ex: res://assets/input/keyboard_a.png e keyboard_a_outline.png
@export var texture_folder := "res://Assets/UI/Inputs/"
@export var texture_prefix := "keyboard_"
@export var normal_suffix := ""
@export var pressed_suffix := "_outline"
@export var prompt_spacing := 80.0
@export var flash_time := 0.1
## Ação -> nome da tecla no arquivo da textura
@export var action_to_key_name := {
	&"Jump": "space",
	&"Forward": "arrow_up",
	&"Backward": "arrow_down",
	&"Left": "arrow_left",
	&"Right": "arrow_right",
	# &"key_a": "a",
	# &"key_d": "d",
}

@onready var timer: Timer = $Timer
@onready var progress_bar: ProgressBar = $ProgressBar
## Node2D vazio onde os Sprite2D das teclas são criados
@onready var prompts: Node2D = $Prompts

signal game_finished(has_won: bool) # True: ganhou - False: perdeu
signal mashPressed(progress: float)

var running := false
var last_side := 0 # -1 esquerda, 1 direita, 0 nenhum (modo ALTERNATE)
var sequence: Array[StringName] = []
var seq_index := 0

var prompt_sprites: Array[Sprite2D] = []
var prompt_actions: Array = []
var texture_cache := {}

# Sempre que o btnCount mudar, a progress bar acompanha
var btnCount: float = 0.0:
	set(value):
		btnCount = clampf(value, 0.0, max_progress)
		if is_node_ready() and progress_bar:
			progress_bar.value = btnCount


func _ready() -> void:
	visible = false
	progress_bar.max_value = max_progress


func start(new_mode: Mode = mode):
	if visible:
		return
	mode = new_mode
	visible = true
	running = true
	btnCount = 0
	last_side = 0
	seq_index = 0

	match mode:
		Mode.MASH:
			timer.one_shot = false
			timer.wait_time = mash_time
			_build_prompts([mash_actions[0]])
		Mode.ALTERNATE:
			timer.one_shot = false
			timer.wait_time = mash_time
			_build_prompts([left_actions[0], right_actions[0]])
			_update_alternate_dim()
		Mode.SEQUENCE:
			timer.one_shot = true
			timer.wait_time = sequence_time
			_generate_sequence()
			_build_prompts(sequence)
	timer.start()


func stop():
	visible = false
	running = false
	timer.stop()
	btnCount = 0
	_clear_prompts()


func _generate_sequence() -> void:
	sequence.clear()
	for i in sequence_length:
		sequence.append(sequence_pool.pick_random())


func _input(event: InputEvent) -> void:
	if not visible or not running:
		return

	match mode:
		Mode.MASH:
			if _pressed_any(event, mash_actions):
				get_viewport().set_input_as_handled()
				_flash(0)
				_add_progress(press_boost)

		Mode.ALTERNATE:
			var side := 0
			if _pressed_any(event, left_actions):
				side = -1
			elif _pressed_any(event, right_actions):
				side = 1
			if side == 0:
				return
			get_viewport().set_input_as_handled()
			# só conta se for o lado oposto ao último
			if side != last_side:
				last_side = side
				_flash(0 if side == -1 else 1)
				_update_alternate_dim()
				_add_progress(press_boost)

		Mode.SEQUENCE:
			for action in sequence_pool:
				if not event.is_action_pressed(action):
					continue
				get_viewport().set_input_as_handled()
				if action == sequence[seq_index]:
					_set_pressed(seq_index, true) # fica com a textura "apertada"
					_advance_sequence()
				elif wrong_press_resets:
					seq_index = 0
					btnCount = 0
					for i in prompt_sprites.size():
						_set_pressed(i, false)
				break


func _pressed_any(event: InputEvent, actions: Array[StringName]) -> bool:
	for action in actions:
		if event.is_action_pressed(action):
			return true
	return false


func _add_progress(amount: float) -> void:
	mashPressed.emit(btnCount / max_progress)
	btnCount += amount
	if btnCount >= max_progress:
		_finish(true)


func _advance_sequence() -> void:
	seq_index += 1
	btnCount = float(seq_index) / sequence.size() * max_progress
	mashPressed.emit(btnCount / max_progress)
	if seq_index >= sequence.size():
		_finish(true)


func _finish(has_won: bool) -> void:
	if not running:
		return # evita emitir o sinal mais de uma vez
	running = false
	timer.stop()
	game_finished.emit(has_won)


func _on_timer_timeout() -> void:
	if not running:
		return
	match mode:
		Mode.SEQUENCE:
			_finish(false) # acabou o tempo
		_:
			btnCount -= decay_rate
			if btnCount <= 0:
				_finish(false)


# ---------- Prompts com Sprite2D ----------

func _build_prompts(actions: Array) -> void:
	_clear_prompts()
	prompt_actions = actions.duplicate()
	var total_width := (actions.size() - 1) * prompt_spacing
	for i in actions.size():
		var sprite := Sprite2D.new()
		sprite.texture = _get_texture(actions[i], false)
		sprite.position.x = i * prompt_spacing - total_width / 2.0
		prompts.add_child(sprite)
		prompt_sprites.append(sprite)


func _clear_prompts() -> void:
	for sprite in prompt_sprites:
		sprite.queue_free()
	prompt_sprites.clear()
	prompt_actions.clear()


func _set_pressed(index: int, pressed: bool) -> void:
	if index >= prompt_sprites.size():
		return
	prompt_sprites[index].texture = _get_texture(prompt_actions[index], pressed)


## Troca para a textura "apertada" e volta ao normal depois de flash_time
func _flash(index: int) -> void:
	if index >= prompt_sprites.size():
		return
	var sprite := prompt_sprites[index]
	var action: StringName = prompt_actions[index]
	sprite.texture = _get_texture(action, true)
	await get_tree().create_timer(flash_time).timeout
	if is_instance_valid(sprite):
		sprite.texture = _get_texture(action, false)


## No ALTERNATE, deixa a próxima tecla esperada em destaque
func _update_alternate_dim() -> void:
	if prompt_sprites.size() < 2:
		return
	var next := -1 # -1 = qualquer lado
	if last_side == -1:
		next = 1
	elif last_side == 1:
		next = 0
	for i in prompt_sprites.size():
		var dim := next != -1 and i != next
		prompt_sprites[i].modulate.a = 0.4 if dim else 1.0


func _key_name(action: StringName) -> String:
	if action_to_key_name.has(action):
		return action_to_key_name[action]
	# fallback: pega o nome da primeira tecla cadastrada na ação
	var events := InputMap.action_get_events(action)
	if not events.is_empty() and events[0] is InputEventKey:
		return events[0].as_text_physical_keycode().to_lower()
	return String(action)


func _get_texture(action: StringName, pressed: bool) -> Texture2D:
	var suffix := pressed_suffix if pressed else normal_suffix
	var path := "%s%s%s%s.png" % [texture_folder, texture_prefix, _key_name(action), suffix]
	if not texture_cache.has(path):
		if ResourceLoader.exists(path):
			texture_cache[path] = load(path)
		else:
			push_warning("Textura não encontrada: " + path)
			texture_cache[path] = null
	return texture_cache[path]
