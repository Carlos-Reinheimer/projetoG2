extends Node

@export var build_ceiling := true
@export var totalFloors: int = 10

@onready var grid_map: GridMap = $"../GridMap"
@onready var player: CharacterBody3D = $"../Player"

var currentFloor: int = 0

func _ready() -> void:
	# previewFloor()
	generateFloor()
	
func generateFloor() -> void:
	var generator := FloorGenerator.new()
	var randomSeed = randi()
	print("randomSeed: ", randomSeed)
	var data := generator.generate(randomSeed)
	var wallId := grid_map.mesh_library.find_item_by_name("Wall")
	var floorId := grid_map.mesh_library.find_item_by_name("Floor")
	var ceilingId := grid_map.mesh_library.find_item_by_name("Ceiling")
	var spawnPlayerPos: Vector3i
	
	for x in data.size.x:
		for z in data.size.y: # y = z on this case
			var cell := Vector2i(x, z)
			var cellType = data.get_cell_type(cell)
			
			if cellType == FloorData.Cell.START:
				spawnPlayerPos = Vector3i(x + 0.5, 1, z + 0.5)
			
			if cellType == FloorData.Cell.WALL:
				grid_map.set_cell_item(Vector3i(x, 0, z), wallId)
			else:
				grid_map.set_cell_item(Vector3i(x, -1, z), floorId)
				if build_ceiling:
					grid_map.set_cell_item(Vector3i(x, 1, z), ceilingId)

	player.global_position = Vector3(spawnPlayerPos.x, spawnPlayerPos.y, spawnPlayerPos.z)

#func previewFloor() -> void:
	#var generator := FloorGenerator.new()
	#for s in [1, 2, 3, 42]:
		#var data := generator.generate(s)
		#print("=== seed %d | %d rooms ===" % [s, data.rooms.size()])
		#print(data.to_ascii())
