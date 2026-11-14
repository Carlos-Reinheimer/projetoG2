@tool
class_name FloorData
extends RefCounted

enum Cell { WALL, ROOM, CORRIDOR, DOOR }
enum Side { LEFT, RIGHT }

var floorSeed: int = 0
var size: Vector2i = Vector2i.ZERO
var corridor: Rect2i = Rect2i()

# Each room: { "rect": Rect2i, "side": Side, "door": Rect2i }
var rooms: Array[Dictionary] = []
var props: Array[Dictionary] = []

## What is at this cell? Anything not covered by a rect is a wall.
func getCellType(cell: Vector2i) -> Cell:
	for room in rooms:
		if room["door"].has_point(cell):
			return Cell.DOOR

	if corridor.has_point(cell):
		return Cell.CORRIDOR

	for room in rooms:
		if room["rect"].has_point(cell):
			return Cell.ROOM

	return Cell.WALL

func toAscii() -> String:
	var out := ""
	for z in size.y:
		var line := ""
		for x in size.x:
			var cell := Vector2i(x, z)
			match getCellType(cell):
				Cell.WALL: line += "#"
				Cell.ROOM: line += "."
				Cell.CORRIDOR: line += ","
				Cell.DOOR: line += "D"
		out += line + "\n"
	return out
