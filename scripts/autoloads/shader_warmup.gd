extends Node

## Preloads and warms up shaders to prevent frame stutters during gameplay
## Spawns particle effects off-screen at startup to force shader compilation

## Particle scenes to precompile
var _particle_scenes: Array[PackedScene] = []

## Position far below the world where warmup particles won't be seen
const WARMUP_POSITION = Vector3(0, -1000, 0)


func _ready() -> void:
	# Defer warmup to ensure scene tree is ready
	_warmup_shaders.call_deferred()


func _warmup_shaders() -> void:
	print("ShaderWarmup: Starting shader warmup...")

	# Load particle scenes
	_load_particle_scenes()

	# Spawn and trigger each particle system
	for scene in _particle_scenes:
		_warmup_particle_scene(scene)

	print("ShaderWarmup: Shader warmup complete (%d particle systems)" % _particle_scenes.size())


func _load_particle_scenes() -> void:
	# Add all particle scenes that need warmup
	_try_load("res://scenes/particles/DestructionParticles.tscn")
	_try_load("res://scenes/particles/TeleportParticles.tscn")
	_try_load("res://scenes/particles/TeleportChargingParticles.tscn")


func _try_load(path: String) -> void:
	if ResourceLoader.exists(path):
		var scene = load(path) as PackedScene
		if scene:
			_particle_scenes.append(scene)
		else:
			push_warning("ShaderWarmup: Failed to load %s" % path)
	else:
		push_warning("ShaderWarmup: Scene not found: %s" % path)


func _warmup_particle_scene(scene: PackedScene) -> void:
	var particles = scene.instantiate() as GPUParticles3D
	if not particles:
		push_warning("ShaderWarmup: Scene is not GPUParticles3D")
		return

	# Add to tree at hidden position
	add_child(particles)
	particles.global_position = WARMUP_POSITION

	# Force shader compilation by emitting
	particles.one_shot = true
	particles.emitting = true

	# Clean up after particles finish (or after a short delay)
	var cleanup_time = particles.lifetime + 0.1
	get_tree().create_timer(cleanup_time).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)


## Register a particle scene for warmup (call before _ready if needed)
func register_particle_scene(path: String) -> void:
	_try_load(path)


## Manually trigger warmup for a specific scene (useful for dynamically loaded content)
func warmup_scene(scene: PackedScene) -> void:
	_warmup_particle_scene(scene)
