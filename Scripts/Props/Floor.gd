class_name Floor
extends Node

const CEILING_HEIGHT = 4.5
const FLOOR_HEIGHT = 0.8
const DEFAULT_FOG_FILL_RATE = 0.05

@export var hasFog: bool = false
@export var startFogHeight: float = CEILING_HEIGHT # lower values = more fog; FLOOR_HEIGHT is the minimum
@export var fogFillRate: float = DEFAULT_FOG_FILL_RATE

var fogNode: FogVolume
var mainController: MainController
var isLevelClear: bool = false

var currentSmokeLevel: float = 0.0

# the "FogVolume" doesn't work at the Floor node, because it needs the World Environment
# but when we load it at the "Main" scene, it works
# when 'hasFog' is enabled, the scene must contain the /Utils -> FloorFogVolume as well

func _ready() -> void:
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
		currentSmokeLevel += fogFillRate * 2.0 * delta
	else:
		currentSmokeLevel -= fogFillRate * mainController.firesOnFloor * delta
	
	currentSmokeLevel = clamp(currentSmokeLevel, FLOOR_HEIGHT, CEILING_HEIGHT)
	fogNode.material.set_shader_parameter("smoke_level", currentSmokeLevel)

func onfloorExtinguished() -> void:
	isLevelClear = true
