extends Node

## Global upgrade manager
## Tracks acquired upgrades, handles trigger events, applies weapon modifiers

signal upgrade_acquired(upgrade_id: String, new_count: int)
signal upgrade_removed(upgrade_id: String, new_count: int)
signal upgrade_triggered(upgrade_id: String, trigger_type: UpgradeTrigger.Type)

## Acquired upgrades: upgrade_id -> stack count
var _acquired_upgrades: Dictionary = {}

## Cached upgrade instances for trigger execution
## upgrade_id -> BaseUpgrade instance
var _upgrade_instances: Dictionary = {}


func _ready() -> void:
	_connect_to_event_bus()


func _connect_to_event_bus() -> void:
	# Combat triggers
	if EventBus.has_signal("enemy_killed"):
		EventBus.enemy_killed.connect(_on_enemy_killed)
	if EventBus.has_signal("enemy_spawned"):
		EventBus.enemy_spawned.connect(_on_enemy_spawned)

	# Weapon triggers
	if EventBus.has_signal("weapon_thrown"):
		EventBus.weapon_thrown.connect(_on_weapon_thrown)
	if EventBus.has_signal("weapon_broken"):
		EventBus.weapon_broken.connect(_on_weapon_broken)
	if EventBus.has_signal("weapon_spawned"):
		EventBus.weapon_spawned.connect(_on_weapon_spawned)

	# Movement triggers
	if EventBus.has_signal("player_dashed"):
		EventBus.player_dashed.connect(_on_player_dashed)
	if EventBus.has_signal("player_teleported"):
		EventBus.player_teleported.connect(_on_player_teleported)

	# Item triggers
	if EventBus.has_signal("item_picked_up"):
		EventBus.item_picked_up.connect(_on_item_picked_up)


#region Public API

## Grant an upgrade to the player (stacks if already owned)
func grant_upgrade(upgrade_id: String, count: int = 1) -> void:
	var upgrade_scene = UpgradeRegistry.get_upgrade(upgrade_id)
	if not upgrade_scene:
		push_warning("UpgradeManager: unknown upgrade '%s'" % upgrade_id)
		return

	# Check max stacks
	var current_count = _acquired_upgrades.get(upgrade_id, 0)
	var base_upgrade = _get_or_create_instance(upgrade_id)

	if base_upgrade and not base_upgrade.can_stack(current_count):
		print("UpgradeManager: %s already at max stacks (%d)" % [upgrade_id, current_count])
		return

	# Add stacks
	var new_count = current_count + count
	if base_upgrade and base_upgrade.max_stacks >= 0:
		new_count = mini(new_count, base_upgrade.max_stacks)

	_acquired_upgrades[upgrade_id] = new_count

	print("UpgradeManager: Granted %s (now x%d)" % [upgrade_id, new_count])
	upgrade_acquired.emit(upgrade_id, new_count)


## Remove upgrade stacks (returns actual amount removed)
func remove_upgrade(upgrade_id: String, count: int = 1) -> int:
	if not _acquired_upgrades.has(upgrade_id):
		return 0

	var current_count = _acquired_upgrades[upgrade_id]
	var removed = mini(count, current_count)
	var new_count = current_count - removed

	if new_count <= 0:
		_acquired_upgrades.erase(upgrade_id)
		_cleanup_instance(upgrade_id)
		new_count = 0
	else:
		_acquired_upgrades[upgrade_id] = new_count

	print("UpgradeManager: Removed %d stack(s) of %s (now x%d)" % [removed, upgrade_id, new_count])
	upgrade_removed.emit(upgrade_id, new_count)
	return removed


## Get current stack count for upgrade
func get_upgrade_count(upgrade_id: String) -> int:
	return _acquired_upgrades.get(upgrade_id, 0)


## Check if player has upgrade
func has_upgrade(upgrade_id: String) -> bool:
	return _acquired_upgrades.has(upgrade_id) and _acquired_upgrades[upgrade_id] > 0


## Get all acquired upgrades as Dictionary[upgrade_id, count]
func get_all_upgrades() -> Dictionary:
	return _acquired_upgrades.duplicate()


## Clear all upgrades (for new run)
func reset_upgrades() -> void:
	_acquired_upgrades.clear()
	_cleanup_all_instances()
	print("UpgradeManager: All upgrades cleared")


## Apply weapon stat modifiers to a newly spawned weapon
func apply_weapon_modifiers(weapon: Node3D) -> void:
	for upgrade_id in _acquired_upgrades:
		var base_upgrade = _get_or_create_instance(upgrade_id)
		if not base_upgrade:
			continue

		var weapon_modifier = base_upgrade.get_weapon_modifier()
		if not weapon_modifier:
			continue

		if weapon_modifier.matches_weapon(weapon):
			var stacks = _acquired_upgrades[upgrade_id]
			weapon_modifier.apply_to_weapon(weapon, stacks)

#endregion


#region Event Handlers

func _on_enemy_killed(enemy: Node3D, killer: Node3D) -> void:
	var context = {
		"enemy": enemy,
		"killer": killer,
		"position": enemy.global_position if enemy else Vector3.ZERO,
		"player": get_tree().get_first_node_in_group("player")
	}
	_fire_trigger(UpgradeTrigger.Type.ENEMY_KILLED, context)


func _on_enemy_spawned(enemy: Node3D) -> void:
	var context = {
		"enemy": enemy,
		"position": enemy.global_position if enemy else Vector3.ZERO,
		"player": get_tree().get_first_node_in_group("player")
	}
	_fire_trigger(UpgradeTrigger.Type.ENEMY_SPAWNED, context)


func _on_weapon_thrown(weapon: Node3D, direction: Vector3, from_crowd: bool) -> void:
	var context = {
		"weapon": weapon,
		"direction": direction,
		"from_crowd": from_crowd,
		"position": weapon.global_position if weapon else Vector3.ZERO,
		"player": get_tree().get_first_node_in_group("player")
	}
	_fire_trigger(UpgradeTrigger.Type.WEAPON_THROWN, context)

	if from_crowd:
		_fire_trigger(UpgradeTrigger.Type.CROWD_THROW, context)


func _on_weapon_broken(weapon: Node3D) -> void:
	var context = {
		"weapon": weapon,
		"position": weapon.global_position if weapon else Vector3.ZERO,
		"player": get_tree().get_first_node_in_group("player")
	}
	_fire_trigger(UpgradeTrigger.Type.WEAPON_BROKEN, context)


func _on_weapon_spawned(weapon: Node3D) -> void:
	# Apply weapon modifiers to new weapon
	apply_weapon_modifiers(weapon)


func _on_player_dashed(direction: Vector3) -> void:
	var player = get_tree().get_first_node_in_group("player")
	var context = {
		"direction": direction,
		"position": player.global_position if player else Vector3.ZERO,
		"player": player
	}
	_fire_trigger(UpgradeTrigger.Type.PLAYER_DASHED, context)


func _on_player_teleported(from_pos: Vector3, to_pos: Vector3) -> void:
	var player = get_tree().get_first_node_in_group("player")
	var context = {
		"from_position": from_pos,
		"to_position": to_pos,
		"position": from_pos,  # Default position is where teleport started
		"player": player
	}
	_fire_trigger(UpgradeTrigger.Type.PLAYER_TELEPORTED, context)


func _on_item_picked_up(item: Node3D, picker: Node3D) -> void:
	var context = {
		"item": item,
		"picker": picker,
		"position": item.global_position if item else Vector3.ZERO,
		"player": picker
	}
	_fire_trigger(UpgradeTrigger.Type.ITEM_PICKED_UP, context)

#endregion


#region Internal

## Fire all trigger upgrades of a specific type
func _fire_trigger(trigger_type: UpgradeTrigger.Type, context: Dictionary) -> void:
	for upgrade_id in _acquired_upgrades:
		var base_upgrade = _get_or_create_instance(upgrade_id)
		if not base_upgrade:
			continue

		var trigger_upgrade = base_upgrade.get_trigger_upgrade()
		if not trigger_upgrade:
			continue

		if trigger_upgrade.trigger != trigger_type:
			continue

		var stacks = _acquired_upgrades[upgrade_id]
		if trigger_upgrade.try_activate(context, stacks):
			upgrade_triggered.emit(upgrade_id, trigger_type)


## Get or create a cached upgrade instance
func _get_or_create_instance(upgrade_id: String) -> BaseUpgrade:
	if _upgrade_instances.has(upgrade_id):
		return _upgrade_instances[upgrade_id]

	var upgrade_scene = UpgradeRegistry.get_upgrade(upgrade_id)
	if not upgrade_scene:
		return null

	var instance = upgrade_scene.instantiate() as BaseUpgrade
	if instance:
		# Add to tree so timers work
		add_child(instance)
		_upgrade_instances[upgrade_id] = instance

	return instance


## Cleanup a cached upgrade instance
func _cleanup_instance(upgrade_id: String) -> void:
	if _upgrade_instances.has(upgrade_id):
		var instance = _upgrade_instances[upgrade_id]
		if is_instance_valid(instance):
			instance.queue_free()
		_upgrade_instances.erase(upgrade_id)


## Cleanup all cached upgrade instances
func _cleanup_all_instances() -> void:
	for upgrade_id in _upgrade_instances:
		var instance = _upgrade_instances[upgrade_id]
		if is_instance_valid(instance):
			instance.queue_free()
	_upgrade_instances.clear()

#endregion
