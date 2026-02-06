extends OnDestroyEffect
class_name ParticleOnDestroyEffect

## Spawns particles when the weapon/item is destroyed
## Attach to any item with WeaponBehaviour to show destruction particles

## Particle scene to spawn (must be GPUParticles3D with one_shot=true)
@export var particle_scene: PackedScene
## Color tint for particles (multiplied with material color)
@export var particle_color: Color = Color.WHITE
## Scale multiplier for the particle effect
@export var scale_multiplier: float = 1.0


func execute() -> void:
	if not particle_scene:
		push_warning("ParticleOnDestroyEffect: no particle_scene assigned")
		return

	if not item:
		push_warning("ParticleOnDestroyEffect: no item reference")
		return

	var particles = particle_scene.instantiate()
	if not particles is GPUParticles3D:
		push_warning("ParticleOnDestroyEffect: particle_scene must be GPUParticles3D")
		particles.queue_free()
		return

	# Reparent to scene root so particles persist after item is freed
	var world = item.get_tree().current_scene
	world.add_child(particles)
	particles.global_position = item.global_position
	particles.scale = Vector3.ONE * scale_multiplier

	# Apply color tint if material supports it
	_apply_color_tint(particles)

	# Ensure one_shot and start emitting
	particles.one_shot = true
	particles.emitting = true

	# Auto-cleanup after particles finish (lifetime + buffer)
	var cleanup_time = particles.lifetime * particles.speed_scale + 0.5
	var cleanup_timer = item.get_tree().create_timer(cleanup_time)
	cleanup_timer.timeout.connect(particles.queue_free)


func _apply_color_tint(particles: GPUParticles3D) -> void:
	if particle_color == Color.WHITE:
		return

	var material = particles.process_material
	if material is ParticleProcessMaterial:
		# Tint the particle color
		var pm = material as ParticleProcessMaterial
		pm.color = pm.color * particle_color
