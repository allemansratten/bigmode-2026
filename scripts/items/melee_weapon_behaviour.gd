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
## Collision mask for what can be hit (default: enemies and items)
@export var hit_collision_mask: int = 12 # Layer 3 (ENEMY) + Layer 4 (ITEM)


## Override attack to perform melee hitbox check
func _attack() -> void:
	if not item or not is_held:
		return

	print("MeleeWeaponBehaviour: attacking with ", item.name)

	# Get attack origin (weapon position or holder position)
	var attack_origin = item.global_position

	# Get attack direction towards mouse cursor
	var attack_direction = _get_mouse_direction(attack_origin)

	# Perform shape cast or area check for hits
	var space_state = item.get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()

	# Create sphere shape for hit detection (reduced size)
	var shape = SphereShape3D.new()
	var attack_radius = swing_range * 0.5  # Make AOE smaller
	shape.radius = attack_radius

	# Position the attack sphere towards the mouse direction
	var attack_distance = swing_range * 0.8
	query.shape = shape
	query.transform = Transform3D(Basis(), attack_origin + attack_direction * attack_distance)
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

	# Create debug visualization
	_create_debug_sphere(attack_origin + attack_direction * attack_distance, attack_radius)


## Apply damage and knockback to hit entity
func _apply_hit(target: Node3D, direction: Vector3) -> void:
	# Apply damage (if target has health/damageable component)
	# TODO: Implement when we have health system
	print("MeleeWeaponBehaviour: hit ", target.name, " for ", damage, " damage")

	# Apply knockback if target is RigidBody
	if target is RigidBody3D:
		var knockback_vector = direction.normalized() * knockback_force
		target.apply_central_impulse(knockback_vector)


## Get attack direction towards mouse cursor
func _get_mouse_direction(from_position: Vector3) -> Vector3:
	var viewport = item.get_viewport()
	var camera = viewport.get_camera_3d()
	if not camera:
		# Fallback to forward direction if no camera
		return -item.global_transform.basis.z

	var mouse_pos = viewport.get_mouse_position()

	# Cast ray from camera through mouse position
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)

	# Project onto XZ plane (ground level)
	var y_level = from_position.y
	if abs(ray_direction.y) > 0.001:
		var t = (y_level - ray_origin.y) / ray_direction.y
		var hit_point = ray_origin + ray_direction * t

		# Calculate direction from attack origin to hit point
		var direction = (hit_point - from_position).normalized()
		return direction

	# Fallback: use ray direction flattened to XZ
	return Vector3(ray_direction.x, 0, ray_direction.z).normalized()


## Create debug visualization sphere for attack range
func _create_debug_sphere(position: Vector3, radius: float) -> void:
	var mesh_instance = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2.0

	# Create semi-transparent red material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.0, 0.0, 0.3) # Red with 30% opacity
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	sphere_mesh.material = material
	mesh_instance.mesh = sphere_mesh

	# Add to scene first
	item.get_tree().root.add_child(mesh_instance)

	# Then set global position (must be in tree first)
	mesh_instance.global_position = position

	# Remove after 0.2 seconds
	await item.get_tree().create_timer(0.2).timeout
	mesh_instance.queue_free()
