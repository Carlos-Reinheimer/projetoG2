class_name Fire 
extends Node3D

const MAX_LIGHT_ENERGY = 2.0
const ENERGY_DECAY = .05
const MIN_REIGNITE_RATIO = 0.3

const EXTINGUISHED_SFX = preload("res://Assets/SFX/Extinguished Flame.mp3")

@onready var reignite_timer: Timer = $"Reignite Timer"
@onready var reignite_particles: GPUParticles3D = $"Reignite Particles"

@onready var animated_flames: GPUParticles3D = $"Animated Flames"
@onready var collision_shape_3d: CollisionShape3D = $FireArea/CollisionShape3D
@onready var omni_light_3d: OmniLight3D = $OmniLight3D
@onready var audio_stream_player_3d: AudioStreamPlayer3D = $AudioStreamPlayer3D

@export var fireResource: FireResource

var health: float = 0.0
var hasReignited: bool = false

var puttOut := false
var p_visual: float
var minHealth: float = 0.0

var mat: ParticleProcessMaterial
var velMinOriginal: float
var velMaxOriginal: float
var scaleMinOriginal: float
var scaleMaxOriginal: float
var isDormant: bool = false

func _ready():
	mat = animated_flames.process_material.duplicate()
	animated_flames.process_material = mat
	reignite_particles.emitting = false
	
	velMinOriginal = mat.initial_velocity_min
	velMaxOriginal = mat.initial_velocity_max
	scaleMinOriginal = mat.scale_min
	scaleMaxOriginal = mat.scale_min
	
	health = fireResource.health
	minHealth = 0.1 if fireResource.reignite else 0.0

func _process(delta):
	if isDormant:
		var progress = 1.0 - reignite_timer.time_left / fireResource.inactiveDuration
		reignite_particles.amount_ratio = lerpf(MIN_REIGNITE_RATIO, 1.0, progress)
	
	if puttOut:
		return
	
	#Recupera vida se não estiver sendo apagado
	health = min(health + delta * 3.0, fireResource.health)
	var p_target := health / fireResource.health
	p_visual = lerp(p_visual, p_target, 1.0 - exp(-3.0 * delta))
	omni_light_3d.light_energy = remap(health, minHealth, fireResource.health, 0.0, MAX_LIGHT_ENERGY) # using the same health scale for the light, so it's consistant
	
	var f: float = lerp(0.15, 1.0, p_visual)
	mat.scale_min = scaleMinOriginal * f
	mat.scale_max = scaleMaxOriginal * f
	mat.initial_velocity_min = velMinOriginal * f
	mat.initial_velocity_max = velMaxOriginal * f

func puttingOut() -> void:
	if puttOut:
		return

	health -= fireResource.decayRate
	health = clampf(health, minHealth, fireResource.health)
	omni_light_3d.light_energy = remap(health, minHealth, fireResource.health, 0.0, MAX_LIGHT_ENERGY) # using the same health scale for the light, so it's consistant
	checkDeath()

func checkDeath() -> void:
	if health <= minHealth:
		collision_shape_3d.set_deferred("disabled", true)
		puttOut = true
		mat.scale_min = 0.15
		mat.scale_max = 1.0
		
		if not fireResource.reignite or (fireResource.reignite and hasReignited):
			audio_stream_player_3d.stream = EXTINGUISHED_SFX
			audio_stream_player_3d.play()
			SignalBus.emit_signal("extinguishFire")
			await get_tree().create_timer(animated_flames.lifetime).timeout
			queue_free()
		else:
			animated_flames.emitting = false
			reignite_timer.wait_time = fireResource.inactiveDuration
			reignite_timer.start()
			reignite_particles.emitting = true
			reignite_particles.amount_ratio = MIN_REIGNITE_RATIO
			isDormant = true

func _on_reignite_timer_timeout() -> void:
	if not fireResource.reignite:
		return
	
	isDormant = false
	reignite_particles.emitting = false
	animated_flames.emitting = true
	hasReignited = true;
	puttOut = false
	collision_shape_3d.set_deferred("disabled", false)
