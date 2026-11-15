extends Button

@export var hoverScale: float = 1.1
@export var duration: float = 0.12

var _tween: Tween

func _ready() -> void:
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	pivot_offset = size / 2

func _on_hover(hovering: bool) -> void:
	if _tween and _tween.is_running():
		_tween.kill()
		
	var target = Vector2.ONE * (hoverScale if hovering else 1.0)
	
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", target, duration)
