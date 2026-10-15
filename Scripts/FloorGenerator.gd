class_name FloorGenerator
extends RefCounted
# RefCounted allow us to create a temporary data object that we can instance to comunicate data
# https://www.youtube.com/watch?v=BI221GaVU_M
# https://forum.godotengine.org/t/when-to-use-refcounted-vs-resource-vs-node/109460
# https://docs.godotengine.org/en/stable/tutorials/best_practices/node_alternatives.html

# Dungeon Generator ref: https://youtu.be/h64U6j_sFgs?si=M_-n2820fQAy07dG

const BASE_WIDTH: int = 35
const BASE_LENGTH: int = 45
const MAX_WIDTH: int = 75
const MAX_LENGTH: int = 125
const WIDTH_GROWTH: int = 4
const LENGTH_GROWTH: int = 8

const MIN_FRONT_ROOM_DEPTH: int = 6
const MIN_BACK_ROOM_DEPTH: int = 4
const SPLIT_ROOM_CHANCE: float = 0.5

const CORRIDOR_WIDTH: int = 7
const MIN_ROOM_LENGTH: int = 8
const MIN_ROOM_WIDTH: int = 5
const MAX_ROOM_LENGTH: int = 14
const DOOR_WIDTH: int = 4
const END_ZONE: int = 3

var _rng = RandomNumberGenerator.new()
var floorWidth: int = BASE_WIDTH
var floorLength: int = BASE_LENGTH

func generate(floorSeed: int, availableProps: Array[Prop], floorLevel: int = 1) -> FloorData:
	_rng.seed = floorSeed

	var data = FloorData.new()
	data.floorSeed = floorSeed
	data.size = Vector2i(BASE_WIDTH, BASE_LENGTH)
	
	var newFloorWidth = floorWidth + (floorLevel - 1) * WIDTH_GROWTH
	var newFloorLength = floorLength + (floorLevel - 1) * LENGTH_GROWTH
	floorWidth = mini(MAX_WIDTH, newFloorWidth) 
	floorLength = mini(MAX_LENGTH, newFloorLength) 
	# The outer ring of cells (x=0, x=W-1, z=0, z=L-1) stays wall
	var innerZStart = 1
	var innerLength = BASE_LENGTH - 2 # Because we want a wall around it

	var minX = MIN_ROOM_WIDTH + 2 # These two are because of the walls
	var maxX = BASE_WIDTH - 2 - CORRIDOR_WIDTH - MIN_ROOM_WIDTH
	var corridorX = _rng.randf_range(minX, maxX)
	#var corridorX = (BASE_WIDTH - CORRIDOR_WIDTH) / 2
	data.corridor = Rect2i(corridorX, innerZStart, CORRIDOR_WIDTH, innerLength)

	# Stairs at the low-Z end, start at the high-Z end.
	data.stairsRect = Rect2i(corridorX, innerZStart, CORRIDOR_WIDTH, END_ZONE)
	data.startRect = Rect2i(corridorX, BASE_LENGTH - 1 - END_ZONE, CORRIDOR_WIDTH, END_ZONE)
	data.startCell = data.startRect.position + data.startRect.size / 2
	
	var lengths = getLengths(innerLength)

	# We create the left and right strips before actually creating the rooms, so we can have different sizes
	# Left strip: x from 1 up to (but not including) the wall left of the corridor
	var leftWallX = corridorX - 1
	var leftX = 1
	var leftWidth = leftWallX - leftX
	fillStrip(data, FloorData.Side.LEFT, leftX, leftWidth, leftWallX, innerZStart, lengths)

	# Right strip: from the wall right of the corridor + 1 up to the outer wall
	var rightWallX = corridorX + CORRIDOR_WIDTH
	var rightX = rightWallX + 1
	var rightWidth = (BASE_WIDTH - 1) - rightX
	fillStrip(data, FloorData.Side.RIGHT, rightX, rightWidth, rightWallX, innerZStart, lengths)

	fillProps(data, innerZStart, lengths, availableProps)
	return data

func getLengths(stripLength: int) -> Array[int]:
	# Every room costs its length + 1 wall cell (except the last), so we work with length + 1
	var nMin = ceili(float(stripLength + 1) / float(MAX_ROOM_LENGTH + 1))
	var nMax = floori(float(stripLength + 1) / float(MIN_ROOM_LENGTH + 1))
	var roomCount = _rng.randi_range(nMin, nMax) # By doing this, we can guarantee to solve the room size below for any number selected

	# We start every room at the minimum, then hand out the leftover cells randomly
	var lengths: Array[int] = []
	lengths.resize(roomCount)
	lengths.fill(MIN_ROOM_LENGTH)
	var totalRoomCells = stripLength - (roomCount - 1)
	var remaining = totalRoomCells - roomCount * MIN_ROOM_LENGTH
	while remaining > 0:
		var i = _rng.randi_range(0, roomCount - 1)
		if lengths[i] < MAX_ROOM_LENGTH:
			lengths[i] += 1
			remaining -= 1

	return lengths

## Splits a vertical strip into rooms. Room lengths plus the 1-cell walls between them add up exactly to the strip length
func fillStrip(data: FloorData, side: FloorData.Side, x: int, width: int, wallX: int, zStart: int, lengths: Array[int]) -> void:
	var z = zStart
	for length in lengths:
		# We can split a room into two if this condition is met
		var shouldSplit = _rng.randf() <= SPLIT_ROOM_CHANCE
		if width >= MIN_BACK_ROOM_DEPTH + 1 + MIN_FRONT_ROOM_DEPTH and shouldSplit:
			var frontDepth = _rng.randi_range(MIN_FRONT_ROOM_DEPTH, width - 1 - MIN_BACK_ROOM_DEPTH)
			var backDepth = width - 1 - frontDepth
			var backDoorZ = _rng.randi_range(z + 1, z + length - DOOR_WIDTH - 1)
			var frontDoorZ = _rng.randi_range(z + 1, z + length - DOOR_WIDTH - 1)
			var backDoor = Rect2i(x + backDepth, backDoorZ, 1, DOOR_WIDTH)
			var frontDoor = Rect2i(wallX, frontDoorZ, 1, DOOR_WIDTH)
			var backRect = Rect2i(x, z, backDepth, length)
			var frontRect = Rect2i(x + backDepth + 1, z, frontDepth, length)
			data.rooms.append({"rect": frontRect, "side": side, "door": frontDoor})
			data.rooms.append({"rect": backRect, "side": side, "door": backDoor})
		else:
			# Door in the wall column facing the corridor, away from the room's corners
			var rect = Rect2i(x, z, width, length)
			var doorZ = _rng.randi_range(z + 1, z + length - DOOR_WIDTH - 1)
			var door = Rect2i(wallX, doorZ, 1, DOOR_WIDTH)
			data.rooms.append({"rect": rect, "side": side, "door": door})
		z += length + 1  # +1 = wall between rooms
		print(x, z)

func fillProps(data: FloorData, zStart: int, lengths: Array[int], availableProps: Array[Prop]) -> void:
	for room in data.rooms:
		var randomProp = availableProps[_rng.randi_range(0, availableProps.size() - 1)]
		data.props.append({"id": randomProp.name, "rect": Rect2i(room.rect.position.x + 2, room.rect.position.y + 2, randomProp.footprint.x, randomProp.footprint.y)})
