class_name ButtonMash extends Control

enum Mode { MASH, ALTERNATE, SEQUENCE }
enum Difficulty { EASY, NORMAL, HARD, INSANE }

@export var mode: Mode = Mode.MASH

@export_group("Dificuldade")
@export var difficulty: Difficulty = Difficulty.NORMAL
## false: usa os valores do Inspector em vez dos presets
@export var use_difficulty_presets := true

@export_group("Mash / Alternate")
@export var mash_time = 0.4
@export var press_boost = 5
@export var decay_rate = 8
@export var max_progress = 100
## Quanto o decay aumenta a cada tick (0 = constante)
@export var decay_growth := 0.0
## Penalidade ao apertar o mesmo lado duas vezes no ALTERNATE (0 = só ignora)
@export var wrong_side_penalty := 0.0
## Quanto o boost vale com a barra quase cheia (1.0 = sempre igual, 0.4 = 40%)
@export var end_boost_ratio := 1.0
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
}

@export_group("Efeitos")
@export var effects_enabled := true
## Tamanho do "soquinho" ao acertar (multiplicador da escala)
@export var correct_punch := 1.3
## Escala ao errar (menor que 1 = encolhe)
@export var wrong_punch := 0.8
@export var fx_time := 0.2
@export var correct_color := Color(0.55, 1.0, 0.55)
@export var wrong_color := Color(1.0, 0.35, 0.35)
@export var shake_strength := 14.0
@export var shake_time := 0.3
@export var particles_enabled := true
## Pulso vermelhinho a cada tick de decay (MASH/ALTERNATE)
@export var decay_pulse := true
@export_subgroup("Sons (opcional)")
@export var press_sound: AudioStream
@export var wrong_sound: AudioStream
@export var win_sound: AudioStream
@export var lose_sound: AudioStream

@onready var timer: Timer = $Timer
## Node2D vazio onde os Sprite2D das teclas são criados
@onready var prompts: Node2D = $Prompts

signal game_finished(has_won: bool) # True: ganhou - False: perdeu
signal mashPressed(progress: float)

const BASE_SCALE := Vector2(1.5, 1.5)

const DIFFICULTY_SETTINGS := {
	Difficulty.EASY: {
		"mash_time": 1, "press_boost": 7, "decay_rate": 6, "decay_growth": 0.0,
		"wrong_side_penalty": 0.0, "end_boost_ratio": 1.0,
		"sequence_length": 4, "sequence_time": 5.0, "wrong_press_resets": false,
	},
	Difficulty.NORMAL: {
		"mash_time": 0.7, "press_boost": 5, "decay_rate": 8, "decay_growth": 0.0,
		"wrong_side_penalty": 0.0, "end_boost_ratio": 0.6,
		"sequence_length": 5, "sequence_time": 4.0, "wrong_press_resets": true,
	},
	Difficulty.HARD: {
		"mash_time": .5, "press_boost": 4, "decay_rate": 10, "decay_growth": 0.5,
		"wrong_side_penalty": 8.0, "end_boost_ratio": 0.4,
		"sequence_length": 7, "sequence_time": 3.0, "wrong_press_resets": true,
	},
	Difficulty.INSANE: {
		"mash_time": .4, "press_boost": 3, "decay_rate": 12, "decay_growth": 1.0,
		"wrong_side_penalty": 12.0, "end_boost_ratio": 0.3,
		"sequence_length": 9, "sequence_time": 2.5, "wrong_press_resets": true,
	},
}

var running := false
var last_side := 0 # -1 esquerda, 1 direita, 0 nenhum (modo ALTERNATE)
var sequence: Array[StringName] = []
var seq_index := 0
var current_decay := 0.0

var prompt_sprites: Array[Sprite2D] = []
var prompt_actions: Array = []
var texture_cache := {}

var prompts_origin := Vector2.ZERO
var sprite_tweens := {}
var shake_tween: Tween

# Sempre que o btnCount mudar, a progress bar acompanha
var btnCount: float = 0.0:
	set(value):
		btnCount = clampf(value, 0.0, max_progress)


func _ready() -> void:
	visible = false
	prompts_origin = prompts.position


func apply_difficulty(d: Difficulty) -> void:
	difficulty = d
	var s: Dictionary = DIFFICULTY_SETTINGS[d]
	for key in s:
		set(key, s[key])


func start(new_mode: Mode = mode, new_difficulty: Difficulty = difficulty):
	if visible:
		return
	if use_difficulty_presets:
		apply_difficulty(new_difficulty)
	mode = new_mode
	visible = true
	running = true
	btnCount = 0
	last_side = 0
	seq_index = 0
	current_decay = decay_rate

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
	if shake_tween and shake_tween.is_valid():
		shake_tween.kill()
	prompts.position = prompts_origin
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
				_fx_correct(0)
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
			var idx := 0 if side == -1 else 1
			# só conta se for o lado oposto ao último
			if side != last_side:
				last_side = side
				_flash(idx)
				_fx_correct(idx)
				_update_alternate_dim()
				_add_progress(press_boost)
			else:
				_fx_wrong(idx)
				if wrong_side_penalty > 0.0:
					btnCount -= wrong_side_penalty
					if btnCount <= 0:
						_finish(false)

		Mode.SEQUENCE:
			for action in sequence_pool:
				if not event.is_action_pressed(action):
					continue
				get_viewport().set_input_as_handled()
				if action == sequence[seq_index]:
					_set_pressed(seq_index, true) # fica com a textura "apertada"
					_fx_correct(seq_index)
					_advance_sequence()
				else:
					_fx_wrong(seq_index)
					if wrong_press_resets:
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
	var ratio = btnCount / max_progress
	btnCount += amount * lerpf(1.0, end_boost_ratio, ratio)
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
	_fx_finish(has_won)
	game_finished.emit(has_won)


func _on_timer_timeout() -> void:
	if not running:
		return
	match mode:
		Mode.SEQUENCE:
			_finish(false) # acabou o tempo
		_:
			btnCount -= current_decay
			current_decay += decay_growth
			if btnCount <= 0:
				_finish(false)
			else:
				_fx_decay_tick()


# ---------- Efeitos ----------

func _fx_correct(index: int) -> void:
	if not effects_enabled or index >= prompt_sprites.size():
		return
	var sprite := prompt_sprites[index]
	_pulse(sprite, correct_punch, correct_color)
	if particles_enabled:
		_burst(sprite.position, correct_color, 10)
	# o som fica mais agudo conforme a barra enche
	_play(press_sound, 1.0 + (btnCount / max_progress) * 0.5)


func _fx_wrong(index: int) -> void:
	if not effects_enabled or index >= prompt_sprites.size():
		return
	_pulse(prompt_sprites[index], wrong_punch, wrong_color)
	_shake()
	_play(wrong_sound)


func _fx_decay_tick() -> void:
	if not effects_enabled or not decay_pulse:
		return
	for sprite in prompt_sprites:
		_pulse(sprite, 0.92, Color(1.0, 0.7, 0.7))


func _fx_finish(has_won: bool) -> void:
	if not effects_enabled:
		return
	if has_won:
		for sprite in prompt_sprites:
			_pulse(sprite, 1.5, correct_color)
			if particles_enabled:
				_burst(sprite.position, correct_color, 18)
		_play(win_sound)
	else:
		for sprite in prompt_sprites:
			_pulse(sprite, 0.7, wrong_color)
		_shake()
		_play(lose_sound)


## Muda escala e cor do sprite de uma vez e volta ao normal com um tween.
## Usa self_modulate para não brigar com o modulate.a do _update_alternate_dim.
func _pulse(sprite: Sprite2D, scale_mult: float, color: Color) -> void:
	var old: Tween = sprite_tweens.get(sprite)
	if old and old.is_valid():
		old.kill()
	sprite.scale = BASE_SCALE * scale_mult
	sprite.self_modulate = color
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sprite, "scale", BASE_SCALE, fx_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "self_modulate", Color.WHITE, fx_time)
	sprite_tweens[sprite] = tw


func _shake() -> void:
	if shake_tween and shake_tween.is_valid():
		shake_tween.kill()
	prompts.position = prompts_origin
	shake_tween = create_tween()
	var steps := 6
	for i in steps:
		var falloff := 1.0 - float(i) / steps
		var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength * falloff
		shake_tween.tween_property(prompts, "position", prompts_origin + offset, shake_time / steps)
	shake_tween.tween_property(prompts, "position", prompts_origin, 0.02)


func _burst(pos: Vector2, color: Color, amount: int = 10) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.45
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 160.0
	p.gravity = Vector2(0, 300)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0
	var grad := Gradient.new()
	grad.set_color(0, color)
	grad.set_color(1, Color(color, 0.0))
	p.color_ramp = grad
	prompts.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _play(stream: AudioStream, pitch := 1.0) -> void:
	if not effects_enabled or stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = pitch
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


# ---------- Prompts com Sprite2D ----------

func _build_prompts(actions: Array) -> void:
	_clear_prompts()
	prompt_actions = actions.duplicate()
	var total_width := (actions.size() - 1) * prompt_spacing
	for i in actions.size():
		var sprite := Sprite2D.new()
		sprite.texture = _get_texture(actions[i], false)
		sprite.position.x = i * prompt_spacing - total_width / 2.0
		sprite.scale = BASE_SCALE
		prompts.add_child(sprite)
		prompt_sprites.append(sprite)


func _clear_prompts() -> void:
	for tw in sprite_tweens.values():
		if tw and tw.is_valid():
			tw.kill()
	sprite_tweens.clear()
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
