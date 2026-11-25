extends SpotLight3D

const TARGET_ENERGY = 5.0

@onready var flashlight: SpotLight3D = $"."
@onready var flashlight_sfx: AudioStreamPlayer = $"../../../FlashlightSFX"

var isOn: bool = false

func _ready() -> void:
	flashlight.light_energy = 0.0

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("Flashlight"):
		flashlight.light_energy = TARGET_ENERGY if not isOn else 0.0
		isOn = !isOn
		flashlight_sfx.play()
