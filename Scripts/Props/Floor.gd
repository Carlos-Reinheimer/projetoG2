class_name Floor
extends Node

enum FLOOR_LIGHTS_BEHAVIOR {NONE, FLICKER, OFF, FLICKER_AND_OFF}

const CEILING_HEIGHT = 4.5
const FLOOR_HEIGHT = 0.8
const DEFAULT_FOG_FILL_RATE = 0.05

var EMISSIVE_LIGHT_MAT = preload("res://Assets/Materials/Emissive/Light Emissive Warm.tres")

@onready var firesParent: Node3D = $Fires

@export var hasFog: bool = false
@export var lightBehavior: FLOOR_LIGHTS_BEHAVIOR = FLOOR_LIGHTS_BEHAVIOR.NONE
@export var startFogHeight: float = CEILING_HEIGHT # lower values = more fog; FLOOR_HEIGHT is the minimum
@export var fogFillRate: float = DEFAULT_FOG_FILL_RATE

const blueFireScene = preload("res://Scenes/Fires/Blue Fire.tscn")

var fogNode: FogVolume
var mainController: MainController
var isLevelClear: bool = false

var currentSmokeLevel: float = 0.0

# the "FogVolume" doesn't work at the Floor node, because it needs the World Environment
# but when we load it at the "Main" scene, it works
# when 'hasFog' is enabled, the scene must contain the /Utils -> FloorFogVolume as well

func _ready() -> void:
	SignalBus.connect("spawnNewFire", onSpawnFire)
	handleFloorLights()
	
	if not hasFog:
		return
	
	SignalBus.connect("floorExtinguished", onfloorExtinguished)
	
	fogNode = get_node("FogVolume")
	mainController = get_tree().current_scene.get_node("Main Controller")
	currentSmokeLevel = clampf(startFogHeight, FLOOR_HEIGHT, CEILING_HEIGHT)
	fogNode.material.set_shader_parameter("smoke_level", currentSmokeLevel)
	
func _process(delta: float) -> void:
	if not hasFog:
		return
	
	if fogNode == null or mainController == null:
		return

	if isLevelClear or mainController.firesOnFloor == 0:
		currentSmokeLevel += fogFillRate * 5.0 * delta
	else:
		currentSmokeLevel -= fogFillRate * mainController.firesOnFloor * delta
	
	currentSmokeLevel = clamp(currentSmokeLevel, FLOOR_HEIGHT, CEILING_HEIGHT)
	fogNode.material.set_shader_parameter("smoke_level", currentSmokeLevel)

func handleFloorLights() -> void:
	if lightBehavior == FLOOR_LIGHTS_BEHAVIOR.NONE:
		EMISSIVE_LIGHT_MAT.emission_energy_multiplier = 1.0
		return
	
	# going through all the lights is ok because 4/5 only have one
	var floorLights = get_tree().get_nodes_in_group("Light")
	match lightBehavior:
		FLOOR_LIGHTS_BEHAVIOR.FLICKER:
			EMISSIVE_LIGHT_MAT.emission_energy_multiplier = 1.0
			for light in floorLights:
				light.updateFlickerState(true)
		FLOOR_LIGHTS_BEHAVIOR.FLICKER_AND_OFF:
			EMISSIVE_LIGHT_MAT.emission_energy_multiplier = 1.0
			for light in floorLights:
				light.updateFlickerState(true)
			await get_tree().create_timer(5).timeout
			for light in floorLights:
				light.updateFlickerState(false)
				light.turnOnOff(false)
			EMISSIVE_LIGHT_MAT.emission_energy_multiplier = 0
		FLOOR_LIGHTS_BEHAVIOR.OFF:
			EMISSIVE_LIGHT_MAT.emission_energy_multiplier = 0
			for light in floorLights:
				light.turnOnOff(false)

func onfloorExtinguished() -> void:
	isLevelClear = true

func onSpawnFire(enemyPos: Vector3) -> void:
	var newFire = blueFireScene.instantiate()
	firesParent.add_child(newFire)
	newFire.global_position = Vector3(enemyPos.x, enemyPos.y, enemyPos.z)
