class_name FloorData
extends RefCounted

enum Cell { WALL, ROOM, CORRIDOR, DOOR, START, STAIRS }
enum Side { LEFT, RIGHT }

# https://docs.godotengine.org/en/stable/classes/class_vector3i.html
var floorSeed: int = 0
var size: Vector2i = Vector2i.ZERO
var corridor: Rect2i = Rect2i()
var startRect: Rect2i = Rect2i()
var stairsRect: Rect2i = Rect2i()
var startCell: Vector2i = Vector2i.ZERO

# Each room: { "rect": Rect2i, "side": Side, "door": Rect2i }
var rooms: Array[Dictionary] = []

## What is at this cell? Anything not covered by a rect is a wall.
func get_cell_type(cell: Vector2i) -> Cell:
	for room in rooms:
		if room["door"].has_point(cell):
			return Cell.DOOR

	if startRect.has_point(cell):
		return Cell.START
	if stairsRect.has_point(cell):
		return Cell.STAIRS
	if corridor.has_point(cell):
		return Cell.CORRIDOR

	for room in rooms:
		if room["rect"].has_point(cell):
			return Cell.ROOM

	return Cell.WALL

func to_ascii() -> String:
	var out := ""
	for z in size.y:
		var line := ""
		for x in size.x:
			var cell := Vector2i(x, z)
			if cell == startCell:
				line += "S"
				continue
			match get_cell_type(cell):
				Cell.WALL: line += "#"
				Cell.ROOM: line += "."
				Cell.CORRIDOR: line += ","
				Cell.DOOR: line += "D"
				Cell.START: line += "s"
				Cell.STAIRS: line += ">"
		out += line + "\n"
	return out
