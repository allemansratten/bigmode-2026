extends UpgradeEffect
class_name AutoShootOnLandEffect

## Makes ranged weapons shoot the nearest enemy when they land after being thrown
## 20% chance per stack to fire

## Chance to fire per stack
const CHANCE_PER_STACK: float = 0.2

## Store weapons we've set up for auto-shooting: weapon -> {ranged_behaviour, stacks}
var _tracked_weapons: Dictionary = {}

func execute(context: Dictionary, stacks: int = 1) -> void:
	DebugConsole.debug_log("AutoShootOnLandEffect: execute() called")

	if not context.has("weapon"):
		DebugConsole.debug_warn("AutoShootOnLandEffect: No 'weapon' in context")
		return

	var weapon = context["weapon"]
	if not weapon:
		DebugConsole.debug_warn("AutoShootOnLandEffect: weapon is null")
		return

	DebugConsole.debug_log("AutoShootOnLandEffect: Processing weapon '%s'" % weapon.name)

	# Find RangedWeaponBehaviour component
	var ranged_behaviour = _get_ranged_behaviour(weapon)
	if not ranged_behaviour:
		DebugConsole.debug_log("AutoShootOnLandEffect: Skipped - weapon '%s' is not ranged" % weapon.name)
		return

	DebugConsole.debug_log("AutoShootOnLandEffect: Found ranged behaviour, setting up land detection (stacks=%d)" % stacks)

	# Set up land detection for this weapon
	_setup_land_detection(weapon, ranged_behaviour, stacks)

func _setup_land_detection(weapon: Node3D, ranged_behaviour, stacks: int) -> void:
	# Connect to ThrowableBehaviour's land detection if available
	var throwable = weapon.get_node_or_null("ThrowableBehaviour")
	if not throwable:
		DebugConsole.debug_warn("AutoShootOnLandEffect: No ThrowableBehaviour on weapon '%s'" % weapon.name)
		return

	if not throwable.has_signal("throw_landed"):
		DebugConsole.debug_warn("AutoShootOnLandEffect: ThrowableBehaviour has no throw_landed signal")
		return

	# Store weapon info for later use (including stacks for chance calculation)
	_tracked_weapons[weapon] = {
		"ranged_behaviour": ranged_behaviour,
		"stacks": stacks
	}

	# Create a callable that captures the weapon reference
	var callback = func(_collision): _on_weapon_landed_for(weapon)

	# Connect with CONNECT_ONE_SHOT so it auto-disconnects after firing
	if not _tracked_weapons.has(weapon.get_instance_id()):
		throwable.throw_landed.connect(callback, CONNECT_ONE_SHOT)
		DebugConsole.debug_log("AutoShootOnLandEffect: Connected throw_landed for weapon '%s'" % weapon.name)

func _on_weapon_landed_for(weapon: Node3D) -> void:
	DebugConsole.debug_log("AutoShootOnLandEffect: throw_landed received for weapon '%s'" % weapon.name)

	if not is_instance_valid(weapon):
		DebugConsole.debug_warn("AutoShootOnLandEffect: Weapon is no longer valid")
		return

	var weapon_data = _tracked_weapons.get(weapon)
	if not weapon_data:
		DebugConsole.debug_warn("AutoShootOnLandEffect: No data stored for weapon")
		return

	var ranged_behaviour = weapon_data.get("ranged_behaviour")
	var stacks: int = weapon_data.get("stacks", 1)

	if not is_instance_valid(ranged_behaviour):
		DebugConsole.debug_warn("AutoShootOnLandEffect: ranged_behaviour is no longer valid")
		_tracked_weapons.erase(weapon)
		return

	# Roll chance: 20% per stack, capped at 100%
	var chance = minf(CHANCE_PER_STACK * stacks, 1.0)
	var roll = randf()
	DebugConsole.debug_log("AutoShootOnLandEffect: Rolling chance %.0f%% (stacks=%d), rolled %.2f" % [chance * 100, stacks, roll])
	if roll > chance:
		DebugConsole.debug_log("AutoShootOnLandEffect: Chance failed, not firing")
		_tracked_weapons.erase(weapon)
		return

	# Find nearest enemy
	var nearest_enemy = _find_nearest_enemy(weapon.global_position)
	if not nearest_enemy:
		DebugConsole.debug_log("AutoShootOnLandEffect: No enemy found to shoot")
		_tracked_weapons.erase(weapon)
		return

	DebugConsole.debug_log("AutoShootOnLandEffect: Found enemy '%s' at distance %.1f" % [nearest_enemy.name, weapon.global_position.distance_to(nearest_enemy.global_position)])

	# Calculate direction to enemy
	var direction = (nearest_enemy.global_position - weapon.global_position).normalized()

	# Force the weapon to shoot at the enemy
	if ranged_behaviour.has_method("fire_in_direction"):
		ranged_behaviour.fire_in_direction(direction)
		DebugConsole.debug_log("AutoShootOnLandEffect: Weapon '%s' auto-fired at enemy '%s'" % [weapon.name, nearest_enemy.name])
	else:
		DebugConsole.debug_warn("AutoShootOnLandEffect: ranged_behaviour has no fire_in_direction method")

	# Clean up tracking
	_tracked_weapons.erase(weapon)

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