extends Node

@export var build_ceiling := true
@export var totalFloors: int = 10
@export var availableProps: Array[Prop]

@onready var grid_map: GridMap = $"../GridMap"
@onready var player: CharacterBody3D = $"../Player"

var stairs = preload("res://Scenes/Utils/Stairs.tscn")
var fire = preload("res://Scenes/Utils/Fire.tscn")
var enemy = preload("res://Scenes/Enemy.tscn")

var currentFloor: int = 0
var firesOnFloor: int = 0
var enemiesOnFloor: int = 0
var currentStairsNode: Node3D

func _ready() -> void:
	SignalBus.connect("loadNextFloor", onLoadNextFloor)
	SignalBus.connect("captureEnemy", onCaptureEnemy)
	SignalBus.connect("extinguishFire", onExtinguishFire)
	
	#previewFloor()
	generateFloor()
	
func onLoadNextFloor() -> void:
	currentFloor += 1
	firesOnFloor = 0
	enemiesOnFloor = 0
	grid_map.clear()
	
	var fires = get_tree().get_nodes_in_group("Fire")
	var enemies = get_tree().get_nodes_in_group("Enemy")
	clean(fires)
	clean(enemies)
	currentStairsNode.queue_free()
	currentStairsNode = null
	
	generateFloor()

func onCaptureEnemy() -> void:
	enemiesOnFloor -= 1
	Stats.ALL_TIME_ENEMIES_CAPUTRED += 1
	checkFloorCondition()
	
func onExtinguishFire() -> void:
	firesOnFloor -= 1
	Stats.ALL_TIME_FIRE_EXTINGUISED += 1
	checkFloorCondition()

func checkFloorCondition() -> void:
	if enemiesOnFloor == 0 and firesOnFloor == 0:
		SignalBus.emit_signal("floorExtinguised")

func clean(elements) -> void:
	for element in elements:
		element.queue_free()

func generateFloor() -> void:
	var generator := FloorGenerator.new()
	var randomSeed = randi()
	var data := generator.generate(randomSeed, availableProps, currentFloor + 1)
	#print("randomSeed: ", randomSeed)

	buildTiles(data)
	spawnNextLevelStairs(data)
	spawnInsideRoom(data)
	spawnProps(data)
	setPlayerSpawnPos(data)

func buildTiles(data: FloorData) -> void:
	#enum Cell { WALL, ROOM, CORRIDOR, DOOR, START, STAIRS }
	var wallId := grid_map.mesh_library.find_item_by_name("Wall")
	var floorId := grid_map.mesh_library.find_item_by_name("Floor")
	var ceilingId := grid_map.mesh_library.find_item_by_name("Ceiling")
	var startId := grid_map.mesh_library.find_item_by_name("Start")
	var endId := grid_map.mesh_library.find_item_by_name("End")
	
	for x in data.size.x:
		for z in data.size.y: # y = z on this case because of the Vector2i thing
			var cell := Vector2i(x, z)
			var cellType = data.getCellType(cell)
			
			if cellType == FloorData.Cell.WALL:
				grid_map.set_cell_item(Vector3i(x, 0, z), wallId)
			else:
				grid_map.set_cell_item(Vector3i(x, -1, z), floorId)
				if build_ceiling:
					grid_map.set_cell_item(Vector3i(x, 1, z), ceilingId)
				if cellType == FloorData.Cell.START:
					grid_map.set_cell_item(Vector3i(x, -1, z), startId)
				if cellType == FloorData.Cell.STAIRS:
					grid_map.set_cell_item(Vector3i(x, -1, z), endId)

func spawnNextLevelStairs(data: FloorData) -> void:
	var stairsRect = data.stairsRect
	var stairsX = stairsRect.position.x + stairsRect.size.x / 2.0
	var stairsZ = stairsRect.position.y + stairsRect.size.y / 2.0
	currentStairsNode = stairs.instantiate()
	add_child(currentStairsNode)
	currentStairsNode.global_position = Vector3(stairsX, 1, stairsZ)

func setPlayerSpawnPos(data: FloorData) -> void:
	var startRect = data.startRect
	var startX = startRect.position.x + startRect.size.x / 2.0
	var startZ = startRect.position.y + startRect.size.y / 2.0
	player.global_position = Vector3(startX, 1, startZ)

func getRandomX(rect: Rect2i) -> float:
	return randi_range(rect.position.x, rect.end.x - 1)

func getRandomZ(rect: Rect2i) -> float:
	return randi_range(rect.position.y, rect.end.y - 1)

func getProp(propName: String):
	for prop in availableProps:
		if prop.name == propName:
			return prop.propScene
	return null

func spawnProps(data: FloorData) -> void:
	for prop in data.props:
		var propScene = getProp(prop.id)
		var newProp = propScene.instantiate()
		add_child(newProp)
		var propRect = prop.rect
		var propX = propRect.position.x + propRect.size.x / 2.0
		var propZ = propRect.position.y + propRect.size.y / 2.0
		newProp.global_position = Vector3(propX, 1, propZ)

func spawnInsideRoom(data: FloorData) -> void:
	for room in data.rooms:
		var rect: Rect2i = room["rect"]
		var randomX = getRandomX(rect)
		var randomZ = getRandomZ(rect)
		spawnFires(rect, randomX, randomZ)
		spawnEnemies(rect, randomX, randomZ)

func spawnFires(rect: Rect2i, randomX: float, randomZ: float) -> void:
	var count := randi_range(0, 3)
	firesOnFloor += count
	for i in count:
		var newFire = fire.instantiate()
		add_child(newFire)
		newFire.global_position = Vector3(randomX + 0.5, 1, randomZ + 0.5)

func spawnEnemies(rect: Rect2i, randomX: float, randomZ: float) -> void:
	var count := randi_range(1, 1)
	enemiesOnFloor += count
	for i in count:
		var newEnemy = enemy.instantiate()
		add_child(newEnemy)
		newEnemy.global_position = Vector3(randomX + 0.5, 1.5, randomZ + 0.5)

func previewFloor() -> void:
	var generator := FloorGenerator.new()
	for s in [1, 2, 3, 42]:
		var data := generator.generate(s, availableProps, currentFloor + 1)
		print("=== seed %d | %d rooms ===" % [s, data.rooms.size()])
		print(data.toAscii())
