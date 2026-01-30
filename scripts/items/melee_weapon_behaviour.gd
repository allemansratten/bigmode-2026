extends "res://scripts/items/weapon_behaviour.gd"
class_name MeleeWeaponBehaviour

## Melee weapon behavior for close-range attacks
## Uses area detection to hit nearby entities

const Layers = preload("res://scripts/core/collision_layers.gd")

## Range of the swing attack
@export var swing_range: float = 1.5
## Arc angle of swing in degrees
@export var swing_angle: float = 90.0
## Knockback force applied to hit entities
@export var knockback_force: float = 5.0
## Collision mask for what can be hit (default: environment + enemies)
@export var hit_collision_mask: int = 5 # Layers 1 (ENVIRONMENT) + 3 (ENEMY)


## Override attack to perform melee hitbox check
func _attack() -> void:
	if not item or not is_held:
		return

	print("MeleeWeaponBehaviour: attacking with ", item.name)

	# Get attack origin (weapon position or holder position)
	var attack_origin = item.global_position
	var attack_direction = - item.global_transform.basis.z # Forward direction

	# Perform shape cast or area check for hits
	var space_state = item.get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()

	# Create sphere shape for hit detection
	var shape = SphereShape3D.new()
	shape.radius = swing_range

	query.shape = shape
	query.transform = Transform3D(Basis(), attack_origin + attack_direction * swing_range * 0.5)
	query.collision_mask = hit_collision_mask

	# Query for overlapping bodies
	var results = space_state.intersect_shape(query, 10)

	# Process hits
	for result in results:
		var hit_body = result["collider"]

		# Don't hit self or holder
		if hit_body == item:
			continue

		_apply_hit(hit_body, attack_direction)

	print("MeleeWeaponBehaviour: hit %d targets" % results.size())


## Apply damage and knockback to hit entity
func _apply_hit(target: Node3D, direction: Vector3) -> void:
	# Apply damage (if target has health/damageable component)
	# TODO: Implement when we have health system
	print("MeleeWeaponBehaviour: hit ", target.name, " for ", damage, " damage")

	# Apply knockback if target is RigidBody
	if target is RigidBody3D:
		var knockback_vector = direction.normalized() * knockback_force
		target.apply_central_impulse(knockback_vector)
