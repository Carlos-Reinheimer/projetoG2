extends Node

var stash: Dictionary = {}

func add(scene_path: String) -> void:
	stash[scene_path] = stash.get(scene_path, 0) + 1

func take_one() -> String:
	for path in stash.keys():
		stash[path] -= 1
		if stash[path] <= 0:
			stash.erase(path)
		return path
	return ""

func total() -> int:
	var n := 0
	for c in stash.values():
		n += c
	return n
