extends Node

@export var build_ceiling := true
@export var totalFloors: int = 10

@onready var grid_map: GridMap = $"../GridMap"
@onready var player: CharacterBody3D = $"../Player"

var stairs = preload("res://Scenes/Utils/Stairs.tscn")
var fire = preload("res://Scenes/Utils/Fire.tscn")

var currentFloor: int = 0
var hasInstantiatedFloor: bool = false

func _ready() -> void:
	# previewFloor()
	generateFloor()
	
func generateFloor() -> void:
	var generator := FloorGenerator.new()
	var randomSeed = randi()
	print("randomSeed: ", randomSeed)
	var data := generator.generate(randomSeed)
	#enum Cell { WALL, ROOM, CORRIDOR, DOOR, START, STAIRS }
	var wallId := grid_map.mesh_library.find_item_by_name("Wall")
	var floorId := grid_map.mesh_library.find_item_by_name("Floor")
	var ceilingId := grid_map.mesh_library.find_item_by_name("Ceiling")
	var startId := grid_map.mesh_library.find_item_by_name("Start")
	var endId := grid_map.mesh_library.find_item_by_name("End")
	var spawnPlayerPos: Vector3i
	var spawnStairsPos: Vector3i
	
	for x in data.size.x:
		for z in data.size.y: # y = z on this case because of the Vector2i thing
			var cell := Vector2i(x, z)
			var cellType = data.get_cell_type(cell)
			
			if cellType == FloorData.Cell.START:
				spawnPlayerPos = Vector3i(x + 0.5, 1, z + 0.5)
			if cellType == FloorData.Cell.STAIRS:
				spawnStairsPos = Vector3i(x + 0.5, 1, z + 0.5)
			
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
					if not hasInstantiatedFloor:
						hasInstantiatedFloor = true
						var newStairs = stairs.instantiate()
						add_child(newStairs)
						# TODO: we should take a look at this later
						newStairs.global_position = Vector3(spawnStairsPos.x, spawnStairsPos.y, spawnStairsPos.z)

	spawnFires(data)
	player.global_position = Vector3(spawnPlayerPos.x, spawnPlayerPos.y, spawnPlayerPos.z)

func spawnFires(data: FloorData) -> void:
	for room in data.rooms:
		var rect: Rect2i = room["rect"]
		var count := randi_range(0, 3)   # how many fires in this room
		for i in count:
			var randomX = randi_range(rect.position.x, rect.end.x - 1)
			var randomZ = randi_range(rect.position.y, rect.end.y - 1)
			var newFire = fire.instantiate()
			add_child(newFire)
			newFire.global_position = Vector3(randomX + 0.5, 1, randomZ + 0.5)

#func previewFloor() -> void:
	#var generator := FloorGenerator.new()
	#for s in [1, 2, 3, 42]:
		#var data := generator.generate(s)
		#print("=== seed %d | %d rooms ===" % [s, data.rooms.size()])
		#print(data.to_ascii())
