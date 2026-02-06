extends UpgradeEffect
class_name SpawnBrickInHandEffect

## Spawns a brick with 1 durability in player's hand when triggered
## Used for "Whenever you throw a non-brick throwable, spawn a 1-durability brick in your hand"

func execute(context: Dictionary, _stacks: int = 1) -> void:
	# Skip if thrown item is already a brick
	if context.has("weapon"):
		var weapon = context["weapon"]
		if weapon and weapon.name.to_lower().contains("brick"):
			DebugConsole.debug_log("SpawnBrickInHandEffect: Skipped - thrown item is already a brick")
			return
	
	var player = get_player(context)
	if not player:
		DebugConsole.debug_warn("SpawnBrickInHandEffect: No player found")
		return
	
	# Don't give brick if player already holding something
	if player.held_item:
		DebugConsole.debug_log("SpawnBrickInHandEffect: Player already holding item")
		return
	
	# Spawn brick from ItemRegistry
	var brick_items = ItemRegistry.get_items_by_name("Brick")
	if brick_items.is_empty():
		DebugConsole.debug_warn("SpawnBrickInHandEffect: No Brick found in ItemRegistry")
		return
	
	var brick_scene = brick_items[0]
	var brick = brick_scene.instantiate()
	
	# Set durability to 1
	var weapon_behaviour = brick.get_node_or_null("WeaponBehaviour")
	if weapon_behaviour:
		weapon_behaviour.current_durability = 1
		weapon_behaviour.max_durability = 1
	
	# Add to room
	var room = get_room()
	if room:
		room.add_child(brick)
	else:
		get_tree().current_scene.add_child(brick)
	
	# Give to player
	brick.global_position = player.global_position + Vector3.UP
	player.pickup_item(brick)
	
	DebugConsole.debug_log("SpawnBrickInHandEffect: Spawned 1-durability brick")

func _get_player(context: Dictionary) -> Node:
	return get_player(context)