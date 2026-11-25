class_name Light
extends Node3D

const MAX_ENERGY = 10

@export var lightSources: Array[Light3D] = []
@export_range(0.1, 5.0) var flickerSpeed: float = 1.0
@export_range(0.1, MAX_ENERGY) var intensityRange: float = MAX_ENERGY
@export_range(0.1, 1.0) var flickerChance: float = 0.15
@export_range(0.01, 1.0, 0.01) var checkInterval: float = 0.1
@export_range(1.0, 20.0) var smoothSpeed: float = 10.0
@export var snap: bool = false

var flickerEnabled: bool = false
var timeAcc: float = 0.0
var targetEnergy: float = MAX_ENERGY
var currentEnergy: float = MAX_ENERGY

func _process(delta: float) -> void:
	processFlicker(delta)
	
func processFlicker(delta: float) -> void:
	if not flickerEnabled:
		return

	timeAcc += delta * flickerSpeed
	if timeAcc >= checkInterval:
		timeAcc = 0.0
		if randf() < flickerChance:
			targetEnergy = MAX_ENERGY * (1.0 - randf_range(0.0, intensityRange))
		else:
			targetEnergy = MAX_ENERGY

	if snap:
		currentEnergy = targetEnergy
	else:
		currentEnergy = lerpf(currentEnergy, targetEnergy, 1.0 - exp(-smoothSpeed * delta))
	applyEnergy()

func applyEnergy() -> void:
	for light in lightSources:
		light.light_energy = currentEnergy

func updateFlickerState(newState: bool) -> void:
	flickerEnabled = newState
	for light in lightSources:
		light.shadow_enabled = !newState

func turnOnOff(isOn: bool) -> void:
	for light in lightSources:
		light.light_energy = MAX_ENERGY if isOn else 0
