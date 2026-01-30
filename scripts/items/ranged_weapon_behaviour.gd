extends "res://scripts/items/weapon_behaviour.gd"
class_name RangedWeaponBehaviour

## Ranged weapon behavior for projectile-based attacks
## Spawns projectiles when attacking

## Projectile scene to spawn
@export var projectile_scene: PackedScene
## Speed of spawned projectiles
@export var projectile_speed: float = 20.0
## Current ammo count (-1 for infinite)
@export var ammo_count: int = -1
## Maximum ammo capacity
@export var max_ammo: int = 30
## Accuracy spread in degrees (0 = perfect accuracy)
@export var spread: float = 0.0
## Offset from weapon position to spawn projectile
@export var projectile_spawn_offset: Vector3 = Vector3(0, 0, -0.5)


## Override attack to spawn projectile
func _attack() -> void:
	if not item:
		return

	# Check ammo
	if ammo_count == 0:
		print("RangedWeaponBehaviour: out of ammo!")
		return

	if not projectile_scene:
		push_warning("RangedWeaponBehaviour: no projectile_scene set for ", item.name)
		return

	print("RangedWeaponBehaviour: firing projectile from ", item.name)

	# Get attack direction
	var spawn_position = item.global_position + item.global_transform.basis * projectile_spawn_offset
	var attack_direction = -item.global_transform.basis.z  # Forward direction

	# Apply spread
	if spread > 0.0:
		var spread_x = randf_range(-spread, spread)
		var spread_y = randf_range(-spread, spread)
		attack_direction = attack_direction.rotated(Vector3.UP, deg_to_rad(spread_x))
		attack_direction = attack_direction.rotated(item.global_transform.basis.x, deg_to_rad(spread_y))

	attack_direction = attack_direction.normalized()

	# Spawn projectile
	var projectile = projectile_scene.instantiate()
	item.get_tree().root.add_child(projectile)
	projectile.global_position = spawn_position

	# Set projectile velocity (if RigidBody3D)
	if projectile is RigidBody3D:
		projectile.linear_velocity = attack_direction * projectile_speed

	# Consume ammo
	if ammo_count > 0:
		ammo_count -= 1
		print("RangedWeaponBehaviour: ammo remaining: ", ammo_count)


## Reload ammo
func reload(amount: int = -1) -> void:
	if amount < 0:
		ammo_count = max_ammo
	else:
		ammo_count = min(max_ammo, ammo_count + amount)

	print("RangedWeaponBehaviour: reloaded to ", ammo_count, " ammo")


## Check if weapon has ammo
func has_ammo() -> bool:
	return ammo_count != 0
