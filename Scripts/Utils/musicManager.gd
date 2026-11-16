extends Node

@onready var music: AudioStreamPlayer = $Music

# Cinco opções de música
const _46B = preload("uid://bwuvsf4h85rwc")
const BONE_YARD_WALTZ___LOOPABLE = preload("uid://c0gf2l38qk5n")
const DISSONANT_WALTZ = preload("uid://cf3jo6een7bdl")
const HAUNTED_GRAVEYARD = preload("uid://drmj5245emc6m")
const INTROMUSIC = preload("uid://b80djgd68nk5g")

func play_music(stream: AudioStream):
	if music.stream == stream and music.playing:
		return
	music.stream = stream
	music.play()

func _ready() -> void:
	play_music(_46B)
