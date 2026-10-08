class_name FloorGenerator
extends RefCounted
# RefCounted allow us to create a temporary data object that we can instance to comunicate data
# https://www.youtube.com/watch?v=BI221GaVU_M
# https://forum.godotengine.org/t/when-to-use-refcounted-vs-resource-vs-node/109460
# https://docs.godotengine.org/en/stable/tutorials/best_practices/node_alternatives.html

# Dungeon Generator ref: https://youtu.be/h64U6j_sFgs?si=M_-n2820fQAy07dG

const FLOOR_WIDTH: int = 30
const FLOOR_LENGTH: int = 45 
const CORRIDOR_WIDTH: int = 5
const MIN_ROOM_LENGTH: int = 6
const MAX_ROOM_LENGTH: int = 14
const DOOR_WIDTH: int = 2
const END_ZONE: int = 3

var _rng := RandomNumberGenerator.new()

func generate(floor_seed: int) -> FloorData:
	_rng.seed = floor_seed

	var data := FloorData.new()
	data.floorSeed = floor_seed
	data.size = Vector2i(FLOOR_WIDTH, FLOOR_LENGTH)

	# The outer ring of cells (x=0, x=W-1, z=0, z=L-1) stays wall
	var innerZStart := 1
	var innerLength := FLOOR_LENGTH - 2 # because we want a wall around it

	# Corridor, centered in X, full inner length
	var corridorX := (FLOOR_WIDTH - CORRIDOR_WIDTH) / 2
	data.corridor = Rect2i(corridorX, innerZStart, CORRIDOR_WIDTH, innerLength)

	# Stairs at the low-Z end, start at the high-Z end.
	data.stairsRect = Rect2i(corridorX, innerZStart, CORRIDOR_WIDTH, END_ZONE)
	data.startRect = Rect2i(corridorX, FLOOR_LENGTH - 1 - END_ZONE, CORRIDOR_WIDTH, END_ZONE)
	data.startCell = data.startRect.position + data.startRect.size / 2

	# We create the left and right strips before actually creating the rooms, so we can have different sizes
	# Left strip: x from 1 up to (but not including) the wall left of the corridor
	var leftWallX := corridorX - 1
	var leftX := 1
	var leftWidth := leftWallX - leftX
	_fill_strip(data, FloorData.Side.LEFT, leftX, leftWidth, leftWallX, innerZStart, innerLength)

	# Right strip: from the wall right of the corridor + 1 up to the outer wall
	var rightWallX := corridorX + CORRIDOR_WIDTH
	var rightX := rightWallX + 1
	var rightWidth := (FLOOR_WIDTH - 1) - rightX
	_fill_strip(data, FloorData.Side.RIGHT, rightX, rightWidth, rightWallX, innerZStart, innerLength)

	return data

## Splits a vertical strip into rooms. Room lengths plus the 1-cell walls between them add up exactly to the strip length
func _fill_strip(data: FloorData, side: FloorData.Side, x: int, width: int, wallX: int, zStart: int, stripLength: int) -> void:
	# Every room costs its length + 1 wall cell (except the last), so we work with length + 1
	var nMin := ceili(float(stripLength + 1) / float(MAX_ROOM_LENGTH + 1))
	var nMax := floori(float(stripLength + 1) / float(MIN_ROOM_LENGTH + 1))
	var roomCount := _rng.randi_range(nMin, nMax) # By doing this, we can guarantee to solve the room size below for any number selected

	# We start every room at the minimum, then hand out the leftover cells randomly
	var lengths: Array[int] = []
	lengths.resize(roomCount)
	lengths.fill(MIN_ROOM_LENGTH)
	var totalRoomCells := stripLength - (roomCount - 1)
	var remaining := totalRoomCells - roomCount * MIN_ROOM_LENGTH
	while remaining > 0:
		var i := _rng.randi_range(0, roomCount - 1)
		if lengths[i] < MAX_ROOM_LENGTH:
			lengths[i] += 1
			remaining -= 1

	var z := zStart
	for length in lengths:
		var rect := Rect2i(x, z, width, length)
		# Door in the wall column facing the corridor, away from the room's corners
		var doorZ := _rng.randi_range(z + 1, z + length - DOOR_WIDTH - 1)
		var door := Rect2i(wallX, doorZ, 1, DOOR_WIDTH)
		data.rooms.append({"rect": rect, "side": side, "door": door})
		z += length + 1  # +1 = wall between rooms
