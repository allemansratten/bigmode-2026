extends UpgradeEffect
class_name AutoShootOnLandEffect

## Makes ranged weapons shoot the nearest enemy when they land after being thrown
## Used for "Whenever you throw a ranged weapon, it shoots the nearest enemy when it lands"

## Store weapons we've set up for auto-shooting
var _tracked_weapons: Dictionary = {}

func execute(context: Dictionary, _stacks: int = 1) -> void:
	if not context.has("weapon"):
		return
	
	var weapon = context["weapon"]
	if not weapon:
		return
	
	# Find RangedWeaponBehaviour component
	var ranged_behaviour = _get_ranged_behaviour(weapon)
	if not ranged_behaviour:
		DebugConsole.debug_log("AutoShootOnLandEffect: Skipped - weapon is not ranged")
		return
	
	# Set up land detection for this weapon
	_setup_land_detection(weapon, ranged_behaviour)

func _setup_land_detection(weapon: Node3D, ranged_behaviour) -> void:
	# Connect to ThrowableBehaviour's land detection if available
	var throwable = weapon.get_node_or_null("ThrowableBehaviour")
	if throwable and throwable.has_signal("throw_landed"):
		# Store weapon info for later use
		_tracked_weapons[weapon] = ranged_behaviour
		
		# Connect to signal (only once)
		if not throwable.throw_landed.is_connected(_on_weapon_landed):
			throwable.throw_landed.connect(_on_weapon_landed)
			DebugConsole.debug_log("AutoShootOnLandEffect: Set up auto-shoot for weapon")

func _on_weapon_landed(collision: KinematicCollision3D) -> void:
	# Find the weapon that landed from our tracked weapons
	var landed_weapon: Node3D = null
	var ranged_behaviour = null
	
	for weapon in _tracked_weapons.keys():
		if weapon and is_instance_valid(weapon):
			# Check if this is the weapon that just landed
			# We'll use the collision body to identify it
			if collision.get_collider() == weapon:
				landed_weapon = weapon
				ranged_behaviour = _tracked_weapons[weapon]
				break
	
	if not landed_weapon or not ranged_behaviour:
		return
	
	# Find nearest enemy
	var nearest_enemy = _find_nearest_enemy(landed_weapon.global_position)
	if not nearest_enemy:
		DebugConsole.debug_log("AutoShootOnLandEffect: No enemy found to shoot")
		_tracked_weapons.erase(landed_weapon)
		return
	
	# Calculate direction to enemy  
	var direction = (nearest_enemy.global_position - landed_weapon.global_position).normalized()
	
	# Force the weapon to shoot at the enemy
	if ranged_behaviour.has_method("fire_projectile"):
		ranged_behaviour.fire_projectile(direction)
		DebugConsole.debug_log("AutoShootOnLandEffect: Weapon auto-fired at enemy")
	
	# Clean up tracking
	_tracked_weapons.erase(landed_weapon)

func _find_nearest_enemy(position: Vector3) -> Node3D:
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return null
	
	var nearest: Node3D = null
	var nearest_distance: float = INF
	
	for enemy in enemies:
		var distance = position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	
	return nearest

func _get_ranged_behaviour(weapon: Node3D):
	var ranged_behaviour = weapon.get_node_or_null("RangedWeaponBehaviour")
	if ranged_behaviour:
		return ranged_behaviour
	
	# Try as direct child
	for child in weapon.get_children():
		if child.get_script() and child.get_script().get_global_name() == "RangedWeaponBehaviour":
			return child
	
	return null