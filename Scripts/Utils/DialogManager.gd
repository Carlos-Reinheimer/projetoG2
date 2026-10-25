extends Control

@onready var character_dialog: RichTextLabel = $Panel/CharacterDialog
@onready var character_name: Label = $Panel/CharacterName
@onready var panel: Panel = $Panel

func _ready() -> void:
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2.ZERO
	panel.modulate.a = 0.0
	SignalBus.floorExtinguised.connect(onFloorExtinguised)

func onFloorExtinguised():
	showDialog("Tutor Rial", ["Andar limpo, soldado", "Pode seguir para o próximo andar", "E cuidado"])

func showDialog( character: String, dialogs: Array[String] ):
	popIn()
	character_name.text = character
	for dialog in dialogs:
		character_dialog.text = dialog
		character_dialog.visible_ratio = 0
	
		var duration = character_dialog.get_total_character_count() * 0.05

		var tween = create_tween()
		tween.tween_property(character_dialog, "visible_ratio", 1.0, duration)
		await tween.finished

		await get_tree().create_timer(1).timeout
	popOut()

func popIn() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	await tween.finished

func popOut() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "scale", Vector2.ZERO, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, 0.2)
	await tween.finished
