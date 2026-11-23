extends Node

@onready var hover_audio_stream_player: AudioStreamPlayer = $"Hover AudioStreamPlayer"
@onready var click_audio_stream_player: AudioStreamPlayer = $"Click AudioStreamPlayer"

var hoverSound: AudioStream
var clickSound: AudioStream

func _ready() -> void:
	hoverSound = hover_audio_stream_player.stream
	clickSound = click_audio_stream_player.stream

func play(player: AudioStreamPlayer, stream: AudioStream) -> void:
	if player.stream != stream:
		player.stream = stream
	
	player.play()

func playHover(stream: AudioStream = null) -> void:
	play(hover_audio_stream_player, stream if stream else hoverSound)

func playClick(stream: AudioStream = null) -> void:
	play(click_audio_stream_player, stream if stream else clickSound)
