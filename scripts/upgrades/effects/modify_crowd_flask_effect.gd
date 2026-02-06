extends UpgradeEffect
class_name ModifyCrowdFlaskEffect

## Modifies crowd throwing behavior to prioritize flasks and make them break on throw
## Used for "The crowd throws more flasks. Flasks break when thrown by the crowd."

## Multiplier for flask weight in crowd throwing (higher = more likely)
@export var flask_weight_multiplier: float = 3.0

func execute(context: Dictionary, _stacks: int = 1) -> void:
	# This effect modifies global crowd behavior when acquired
	# Connect to EventBus crowd throw events to modify behavior
	if not EventBus.crowd_throw_requested.is_connected(_on_crowd_throw_requested):
		EventBus.crowd_throw_requested.connect(_on_crowd_throw_requested)
		DebugConsole.debug_log("ModifyCrowdFlaskEffect: Connected to crowd throw events")

func _on_crowd_throw_requested(categories: Array, throw_urgency: float = 1.0) -> void:
	# Modify the category request to prioritize flask items
	# Add THROWN category if not present (flasks are throwable)
	if not categories.has(ItemCategories.Category.THROWN):
		categories.append(ItemCategories.Category.THROWN)
	
	# Request specific flask items from ItemRegistry
	var flask_items = ItemRegistry.get_items_matching_any([ItemCategories.Category.THROWN])
	var flask_candidates = []
	
	for item_scene in flask_items:
		# Check if it's a flask by name
		var scene_name = item_scene.resource_path.get_file().get_basename().to_lower()
		if "flask" in scene_name or "bottle" in scene_name:
			flask_candidates.append(item_scene)
	
	if flask_candidates.is_empty():
		return
	
	# Spawn a flask item with modified durability
	var flask_scene = flask_candidates.pick_random()
	var flask = flask_scene.instantiate()
	
	# Make flask break instantly when thrown by crowd
	var weapon_behaviour = flask.get_node_or_null("WeaponBehaviour")
	if weapon_behaviour:
		weapon_behaviour.max_durability = 1
		weapon_behaviour.current_durability = 1
	
	# Add to scene
	var room = get_room()
	if room:
		room.add_child(flask)
	else:
		get_tree().current_scene.add_child(flask)
	
	# Position above player and throw
	var player = get_tree().get_first_node_in_group("player")
	if player:
		flask.global_position = player.global_position + Vector3(randf_range(-3, 3), 5, randf_range(-3, 3))
		
		# Apply throwing force toward player
		var direction = (player.global_position - flask.global_position).normalized()
		if flask is RigidBody3D:
			flask.apply_impulse(direction * 10 + Vector3.DOWN * 2)
	
	DebugConsole.debug_log("ModifyCrowdFlaskEffect: Crowd threw fragile flask")