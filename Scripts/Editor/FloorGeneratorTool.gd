@tool
extends EditorScript

const FLOORS_PER_RUN = 15
const MESH_LIBRARY = "res://Tiles/FloorTiles.meshlib"

func _run() -> void:
	var floorCount = 0
	for level in FLOORS_PER_RUN:
		var randomSeed = randi()
		var floorOutput = "res://Scenes/Floors/Floor_" + str(floorCount) + ".tscn"
		var data := FloorGenerator.new().generate(randomSeed, floorCount)
		var root := Node3D.new()
		root.name = "Floor"
		
		var gridMap := GridMap.new()
		gridMap.name = "Geometry"
		gridMap.mesh_library = load(MESH_LIBRARY)
		gridMap.cell_size = Vector3(1, 5, 1)
		root.add_child(gridMap)
		gridMap.owner = root # without this line the node is NOT saved

		var wallId := gridMap.mesh_library.find_item_by_name("Wall")
		var floorId := gridMap.mesh_library.find_item_by_name("Floor")
		var ceilingId := gridMap.mesh_library.find_item_by_name("Ceiling")
		
		for x in data.size.x:
			for z in data.size.y: # y = z on this case because of the Vector2i thing
				var cell := Vector2i(x, z)
				var cellType = data.getCellType(cell)
				
				if cellType == FloorData.Cell.WALL:
					gridMap.set_cell_item(Vector3i(x, 0, z), wallId)
				else:
					gridMap.set_cell_item(Vector3i(x, -1, z), floorId)
					gridMap.set_cell_item(Vector3i(x, 1, z), ceilingId)

		var packed := PackedScene.new()
		packed.pack(root)
		ResourceSaver.save(packed, floorOutput)
		root.free()
		floorCount += 1
