extends Node3D

const MAX_VALUE = 1
const BASE_PROGRESS = .05
const PROGRESS_PER_FIRE: float = 0.005
const PROGRESS_PER_ENEMY: float = 0.002

@onready var mask_view: MeshInstance3D = $"Mask/Mask View"

var fireProgress: float = 0
var isRunning: bool = false
var isGameOver: bool = false
var currentFireCount: int = 0
var currentEnemyCount: int = 0
var maskMat: ShaderMaterial

func _ready() -> void:
	SignalBus.connect("setupFloor", onSetupFloor)
	SignalBus.connect("captureEnemy", onCaptureEnemy)
	SignalBus.connect("extinguishFire", onExinguishFire)
	SignalBus.connect("loadNextFloor", onLoadNextFloor)
	SignalBus.connect("restartFloor", restartFloor)
	SignalBus.connect("spawnNewFire", onSpawnFire)
	
	maskMat = mask_view.get_active_material(0)
	updateMaskFrost(0)
	
func _process(delta: float) -> void:
	if not isRunning:
		return
	
	var fireWeight = PROGRESS_PER_FIRE * currentFireCount
	var enemyWeight = PROGRESS_PER_ENEMY * currentEnemyCount
	var progress = fireWeight + enemyWeight
	if progress > 0:
		fireProgress += BASE_PROGRESS * sqrt(progress) * delta # sqrt() because oterwise this would be linear, and on lower floors, it would fill up waay too fast; this mitigates it
	else:
		fireProgress -= 0.2 * delta # decreasing the "forst" shader value so players can see again
	
	fireProgress = clampf(fireProgress, 0, MAX_VALUE)
	if isGameOver:
		return
	
	updateMaskFrost(fireProgress)
	if fireProgress == MAX_VALUE:
		isGameOver = true
		SignalBus.emit_signal("endGame")

func onSetupFloor():
	updateMaskFrost(0)
	
	currentFireCount = get_tree().get_nodes_in_group("Fire").size()
	currentEnemyCount = get_tree().get_nodes_in_group("Enemy").size()
	isRunning = true
	isGameOver = false

func updateMaskFrost(value: float) -> void:
	maskMat.set_shader_parameter("fog_amount", value)

func onCaptureEnemy():
	currentEnemyCount -= 1

func onExinguishFire():
	currentFireCount -= 1

func onSpawnFire(enemyPos: Vector3) -> void:
	currentFireCount += 1

func onLoadNextFloor():
	isRunning = false
	updateMaskFrost(0)

func restartFloor() -> void:
	isRunning = false
	updateMaskFrost(0)
	fireProgress = 0
