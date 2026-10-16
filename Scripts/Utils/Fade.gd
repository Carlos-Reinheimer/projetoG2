extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect

func _ready() -> void:
	color_rect.color.a = 0.0
	
func fade(targetAlpha: float, duration: float = 1.0):
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", targetAlpha, duration)
	return tween
