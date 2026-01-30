extends EnemyAttackBehaviour
class_name RangedAttackBehaviour

## Ranged attack behavior
## Attacks target from a distance by spawning projectiles

@export var damage: float = 8.0
@export var attack_range: float = 10.0
@export var attack_cooldown: float = 2.0  # Seconds between attacks
@export var projectile_speed: float = 15.0

# TODO: Add projectile scene when we have one
# @export var projectile_scene: PackedScene

var time_since_last_attack: float = 0.0


func _process(delta: float):
	# Update cooldown timer
	if time_since_last_attack < attack_cooldown:
		time_since_last_attack += delta


func can_attack(enemy: Node3D, target: Node3D) -> bool:
	if not target:
		return false

	# Check cooldown
	if time_since_last_attack < attack_cooldown:
		return false

	# Check range
	var distance := enemy.global_position.distance_to(target.global_position)
	if distance > attack_range:
		return false

	# Check line of sight (basic version - no obstacles check yet)
	return _has_line_of_sight(enemy, target)


func execute_attack(enemy: Node3D, target: Node3D) -> void:
	# Reset cooldown
	time_since_last_attack = 0.0

	# TODO: Spawn projectile when we have projectile system
	# For now, just apply damage directly (placeholder)
	if target.has_method("take_damage"):
		target.take_damage(damage, enemy)
		print("Ranged enemy attacked for %s damage (placeholder - no projectile yet)" % damage)

	# TODO: Play attack animation
	# TODO: Trigger attack sound effect


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
