extends Node

func _ready() -> void:
	var generator := FloorGenerator.new()
	for s in [1, 2, 3, 42]:
		var data := generator.generate(s)
		print("=== seed %d | %d rooms ===" % [s, data.rooms.size()])
		print(data.to_ascii())
