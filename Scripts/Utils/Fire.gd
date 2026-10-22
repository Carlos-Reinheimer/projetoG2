extends Node3D

@onready var flames: GPUParticles3D = $Flames

const MAX_HEALTH : float = 20.0
var health := MAX_HEALTH # Trocar por uma progress bar
var firePoints : float = 2
var puttOut := false
var p_visual: float

var mat: ParticleProcessMaterial
var velMinOriginal: float
var velMaxOriginal: float
var scaleMinOriginal: float
var scaleMaxOriginal: float

func _ready():
	mat = flames.process_material.duplicate()
	flames.process_material = mat
	
	velMinOriginal = mat.initial_velocity_min
	velMaxOriginal = mat.initial_velocity_max
	scaleMinOriginal = mat.scale_min
	scaleMaxOriginal = mat.scale_min

func _on_timer_timeout() -> void:
	queue_free()

func puttingOut() -> void:
	if puttOut:
		return
	health -= 1
	checkDeath()

func checkDeath() -> void:
	if health <= 0:
		SignalBus.emit_signal("extinguishFire", firePoints)
		puttOut = true
		$FireArea/CollisionShape3D.set_deferred("disabled", true)
		flames.emitting = false
		await get_tree().create_timer(flames.lifetime).timeout
		queue_free()

func _process(delta):
	if puttOut:
		return
	
	#Recupera vida se não estiver sendo apagado
	health = min(health + delta * 3.0, MAX_HEALTH)
	var p_target := health / MAX_HEALTH
	p_visual = lerp(p_visual, p_target, 1.0 - exp(-3.0 * delta))
	
	var f: float = lerp(0.15, 1.0, p_visual)
	mat.scale_min = scaleMinOriginal * f
	mat.scale_max = scaleMaxOriginal * f
	mat.initial_velocity_min = velMinOriginal * f
	mat.initial_velocity_max = velMaxOriginal * f
