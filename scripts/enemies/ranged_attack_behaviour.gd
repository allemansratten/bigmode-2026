extends EnemyAttackBehaviour
class_name RangedAttackBehaviour

## Ranged attack behavior
## Attacks target from a distance by spawning projectiles

@export var damage: float = 8.0
@export var attack_range: float = 10.0
@export var attack_cooldown: float = 2.0  # Seconds between attacks
@export var projectile_speed: float = 15.0
@export var projectile_scene: PackedScene = preload("res://scenes/items/Projectile.tscn")
@export var attack_sound: AudioStream  # Sound to play when attack starts
@export var attack_sound_delay: float = 0.0  # Delay before playing attack sound

var _cooldown_timer: Timer


func _ready() -> void:
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = true
	add_child(_cooldown_timer)


func can_attack(enemy: Node3D, target: Node3D) -> bool:
	if not target:
		return false

	# Only attack when standing still (not repositioning or retreating)
	if "is_moving" in enemy and enemy.is_moving:
		return false

	# Check cooldown
	if not _cooldown_timer.is_stopped():
		return false

	# Check range
	var distance := enemy.global_position.distance_to(target.global_position)
	if distance > attack_range:
		return false

	# Check line of sight (basic version - no obstacles check yet)
	return _has_line_of_sight(enemy, target)


func execute_attack(enemy: Node3D, target: Node3D) -> void:
	# Start cooldown timer
	_cooldown_timer.start(attack_cooldown)

	# Spawn projectile
	if not projectile_scene:
		push_warning("No projectile scene set for ranged attack")
		return

	var projectile := projectile_scene.instantiate() as Projectile
	if not projectile:
		push_error("Projectile scene did not instantiate as Projectile")
		return

	# Add to scene at enemy position (slightly above center)
	var spawn_position := enemy.global_position + Vector3.UP * 0.8
	enemy.get_parent().add_child(projectile)
	projectile.global_position = spawn_position

	# Calculate direction to target
	var direction := (target.global_position + Vector3.UP * 0.8 - spawn_position).normalized()

	# Initialize projectile
	projectile.initialize(direction, enemy, damage)
	projectile.speed = projectile_speed

	# Play attack sound
	if attack_sound:
		if attack_sound_delay > 0.0:
			get_tree().create_timer(attack_sound_delay).timeout.connect(func(): Audio.play_sound(attack_sound, Audio.Channels.SFX))
		else:
			Audio.play_sound(attack_sound, Audio.Channels.SFX)


func get_attack_range() -> float:
	return attack_range


## Basic line of sight check
func _has_line_of_sight(enemy: Node3D, target: Node3D) -> bool:
	var space_state := enemy.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		enemy.global_position + Vector3.UP * 0.8,  # Eye level
		target.global_position + Vector3.UP * 0.8
	)
	# Ignore enemy collision layer
	query.collision_mask = 1 | 2  # Environment and player

	var result := space_state.intersect_ray(query)

	# If we hit something, check if it's the target
	if result.is_empty():
		return true

	var hit_collider = result.get("collider")
	return hit_collider == target
