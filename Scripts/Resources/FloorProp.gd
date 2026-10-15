class_name Prop
extends Resource

enum PlacementType { HugWall, FreeForm }

@export var name: String = ""
@export var propScene: PackedScene
@export var footprint: Vector2i # this is the size used on the cell Rect2i
@export var placementType: PlacementType
