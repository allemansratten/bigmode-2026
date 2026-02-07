extends Node
class_name ItemSpawningManager

## Manages item spawning for a room
## Attach to room root; spawn items from spawn points to throw targets
##
## NOTE: allowed_categories should contain type/specific tags only (WEAPON, MELEE, etc.)
## Rarity is selected separately based on wave progression and crowd excitement.

const Categories = preload("res://scripts/core/item_categories.gd")

## Tags that items must match to spawn in this room (uses matches_any)
## Should NOT include rarity tags - rarity is handled by weighted selection
@export var allowed_categories: Array[Categories.Category] = []

## Throw force magnitude
@export var throw_force: float = 10.0

## Throw arc height multiplier (0 = direct, higher = more arc)
@export var arc_height: float = 1.0

## Rarity weight configuration
@export_group("Rarity Weights")
## Base weights for each rarity tier (before progression scaling)
@export var base_weight_common: float = 100.0
@export var base_weight_uncommon: float = 40.0
@export var base_weight_rare: float = 15.0
@export var base_weight_epic: float = 5.0

## How many waves until full progression (rarity scaling maxes out)
@export var max_wave_for_scaling: int = 10

## How much wave count influences rarity (0-1)
@export var wave_influence: float = 0.7
## How much excitement influences rarity (0-1, should sum to ~1 with wave_influence)
@export var excitement_influence: float = 0.3

## Reference to the room node
var room: Node3D

## Cached spawn points
var spawn_points: Array[ItemSpawnPoint] = []

## Cached throw targets
var throw_targets: Array[ItemThrowTarget] = []

## Cached valid items (filtered by allowed categories)
var valid_items: Array[PackedScene] = []

## Cached valid items grouped by rarity (for weighted selection)
var valid_items_by_rarity: Dictionary = {}


func _ready() -> void:
	room = get_parent() as Node3D
	if not room:
		push_error("ItemSpawningManager must be child of room Node3D")
		return

	_cache_spawn_nodes()
	_cache_valid_items()

	# Connect to crowd throw requests from upgrade effects
	EventBus.crowd_throw_requested.connect(_on_crowd_throw_requested)


## Cache all ItemSpawnPoint and ItemThrowTarget children
func _cache_spawn_nodes() -> void:
	spawn_points.clear()
	throw_targets.clear()

	# Look for spawn points and targets as children of this manager
	for child in get_children():
		if child is ItemSpawnPoint:
			spawn_points.append(child)
		elif child is ItemThrowTarget:
			throw_targets.append(child)

	if spawn_points.is_empty():
		push_error("ItemSpawningManager %s: no spawn points found" % name)
	if throw_targets.is_empty():
		push_error("ItemSpawningManager %s: no throw targets found" % name)

	print("ItemSpawningManager: found %d spawn points, %d throw targets" % [spawn_points.size(), throw_targets.size()])


## Cache items that match allowed categories
func _cache_valid_items() -> void:
	valid_items.clear()
	valid_items_by_rarity.clear()

	# Filter out any rarity tags from allowed_categories (they should be type/specific only)
	var type_categories = ItemRegistry.filter_non_rarity_categories(allowed_categories)

	# Query ItemRegistry for items matching our type/specific categories
	if type_categories.is_empty():
		# If no categories specified, use all items
		valid_items = ItemRegistry.all_items.duplicate()
	else:
		valid_items = ItemRegistry.get_items_matching_any(type_categories)

	if valid_items.is_empty():
		push_error("ItemSpawningManager: no items match allowed categories")

	# Cache rarity groupings for weighted selection
	valid_items_by_rarity = ItemRegistry.group_items_by_rarity(valid_items)

	print("ItemSpawningManager: %d items match allowed categories %s" % [valid_items.size(), type_categories])


## Spawn a random item matching room's allowed categories with rarity weighting
func spawn_item() -> Node3D:
	# Select item using weighted rarity (use cached grouping)
	var item_scene = _select_item_with_rarity_weight(valid_items, valid_items_by_rarity)
	if not item_scene:
		push_error("ItemSpawningManager: no valid item to spawn")
		return null

	var spawn_point = spawn_points.pick_random()
	var throw_target = _pick_weighted_target()

	# Instantiate item
	var item = item_scene.instantiate() as Node3D
	if not item:
		push_error("ItemSpawningManager: failed to instantiate item")
		return null

	room.add_child(item)
	item.global_position = spawn_point.global_position

	# Emit global event for upgrade system (weapon modifiers applied here)
	EventBus.weapon_spawned.emit(item)

	_throw_item(item, spawn_point.global_position, throw_target.global_position)

	return item


## Select an item using weighted rarity based on wave progression and excitement
## If grouped_by_rarity is provided, uses that cache; otherwise groups items dynamically
func _select_item_with_rarity_weight(items: Array[PackedScene], grouped_by_rarity: Dictionary = {}) -> PackedScene:
	if items.is_empty():
		return null

	# Use provided grouping or compute it
	var grouped: Dictionary
	if grouped_by_rarity.is_empty():
		grouped = ItemRegistry.group_items_by_rarity(items)
	else:
		grouped = grouped_by_rarity

	# Calculate current rarity weights
	var weights = _calculate_rarity_weights()

	# Build weighted selection array of rarities that have items
	var rarity_options: Array[Categories.Category] = []
	var rarity_weights: Array[float] = []

	for rarity in [Categories.Category.COMMON, Categories.Category.UNCOMMON,
				   Categories.Category.RARE, Categories.Category.EPIC]:
		if grouped[rarity].size() > 0:
			rarity_options.append(rarity)
			rarity_weights.append(weights[rarity])

	if rarity_options.is_empty():
		# Fallback: pick any item randomly
		return items.pick_random()

	# Select rarity tier using weighted random
	var selected_rarity = _weighted_random_select(rarity_options, rarity_weights)

	# Pick random item from selected rarity tier
	var rarity_items: Array = grouped[selected_rarity]
	return rarity_items.pick_random()


## Calculate rarity weights based on wave progression and excitement level
func _calculate_rarity_weights() -> Dictionary:
	# Get current wave and excitement
	var current_wave = _get_current_wave()
	var excitement = _get_excitement_level()

	# Calculate progression factor (0.0 to 1.0)
	var wave_factor = clampf(float(current_wave) / float(max_wave_for_scaling), 0.0, 1.0)
	var excitement_factor = clampf(excitement / 100.0, 0.0, 1.0)

	var progression = (wave_factor * wave_influence) + (excitement_factor * excitement_influence)

	# Apply progression scaling to base weights
	# COMMON decreases, rarer items increase
	var weights: Dictionary = {
		Categories.Category.COMMON: base_weight_common * (1.0 - progression * 0.8),
		Categories.Category.UNCOMMON: base_weight_uncommon * (1.0 + progression * 0.5),
		Categories.Category.RARE: base_weight_rare * (1.0 + progression * 2.0),
		Categories.Category.EPIC: base_weight_epic * (1.0 + progression * 4.0),
	}

	# Ensure minimum weights
	for rarity in weights.keys():
		weights[rarity] = maxf(weights[rarity], 1.0)

	return weights


## Get current wave number from EnemySpawner in room
func _get_current_wave() -> int:
	if not room:
		return 1

	var enemy_spawner = room.get_node_or_null("EnemySpawner") as EnemySpawner
	if enemy_spawner:
		return maxi(enemy_spawner.get_current_wave(), 1)

	return 1


## Get excitement level from CrowdManager
func _get_excitement_level() -> float:
	var crowd_manager = get_tree().get_first_node_in_group("crowd_manager")
	if crowd_manager and "excitement_level" in crowd_manager:
		return crowd_manager.excitement_level
	return 0.0


## Weighted random selection from parallel arrays
func _weighted_random_select(options: Array[Categories.Category], weights: Array[float]) -> Categories.Category:
	var total_weight = 0.0
	for w in weights:
		total_weight += w

	var rand_value = randf() * total_weight
	var cumulative = 0.0

	for i in range(options.size()):
		cumulative += weights[i]
		if rand_value <= cumulative:
			return options[i]

	# Fallback
	return options[0]


## Pick a weighted random throw target
func _pick_weighted_target() -> ItemThrowTarget:
	if throw_targets.size() == 1:
		return throw_targets[0]

	# Calculate total weight
	var total_weight = 0.0
	for target in throw_targets:
		total_weight += target.weight

	# Pick random value
	var rand_value = randf() * total_weight

	# Find target
	var cumulative = 0.0
	for target in throw_targets:
		cumulative += target.weight
		if rand_value <= cumulative:
			return target

	# Fallback
	return throw_targets[0]


## Apply physics impulse to throw item towards target
func _throw_item(item: Node3D, from: Vector3, to: Vector3) -> void:
	var rigid_body = item as RigidBody3D
	if not rigid_body:
		push_warning("ItemSpawningManager: item is not RigidBody3D, cannot throw")
		return

	# Unfreeze and set inertia for proper physics response
	rigid_body.freeze = false
	rigid_body.inertia = Vector3(1, 1, 1)

	# Mark as crowd throw if item has ThrowableBehaviour (prevents durability damage)
	var throwable = item.get_node_or_null("ThrowableBehaviour") as ThrowableBehaviour
	if throwable:
		throwable.mark_as_crowd_throw()

	# Calculate throw direction with arc (same for all items)
	var direction = (to - from).normalized()
	var distance = from.distance_to(to)

	# Add upward component for arc
	var throw_vector = direction * throw_force
	throw_vector.y += arc_height * sqrt(distance)

	# Apply impulse
	rigid_body.apply_central_impulse(throw_vector)

	# Apply spin for visual rotation
	var spin_axis = direction.cross(Vector3.DOWN).normalized()
	if spin_axis.length_squared() > 0.01:
		rigid_body.apply_torque_impulse(spin_axis * 15.0)


## Handle crowd throw requests from upgrade effects
func _on_crowd_throw_requested(categories: Array) -> void:
	if spawn_points.is_empty() or throw_targets.is_empty():
		push_warning("ItemSpawningManager: cannot handle crowd throw, no spawn points or targets")
		return

	spawn_item_with_categories(categories)


## Spawn an item matching specific categories (for crowd throws from upgrades)
## Uses weighted rarity selection based on wave/excitement
func spawn_item_with_categories(categories: Array) -> Node3D:
	# Get items matching the requested categories
	var matching_items: Array[PackedScene] = []
	var use_cached_grouping := false

	if categories.is_empty():
		# Use room's default categories (can use cached grouping)
		matching_items = valid_items
		use_cached_grouping = true
	else:
		# Convert to typed array and filter out rarity tags
		var typed_categories: Array[Categories.Category] = []
		for cat in categories:
			typed_categories.append(cat as Categories.Category)

		# Filter to type/specific categories only
		var type_categories = ItemRegistry.filter_non_rarity_categories(typed_categories)

		if type_categories.is_empty():
			matching_items = valid_items
			use_cached_grouping = true
		else:
			matching_items = ItemRegistry.get_items_matching_any(type_categories)

	if matching_items.is_empty():
		push_warning("ItemSpawningManager: no items match requested categories %s" % [categories])
		return null

	# Select item using weighted rarity (use cache when possible)
	var grouped = valid_items_by_rarity if use_cached_grouping else {}
	var item_scene = _select_item_with_rarity_weight(matching_items, grouped)
	if not item_scene:
		push_error("ItemSpawningManager: failed to select item with rarity weight")
		return null

	var spawn_point = spawn_points.pick_random()
	var throw_target = _pick_weighted_target()

	# Instantiate item
	var item = item_scene.instantiate() as Node3D
	if not item:
		push_error("ItemSpawningManager: failed to instantiate item")
		return null

	room.add_child(item)
	item.global_position = spawn_point.global_position

	# Emit global event for upgrade system (weapon modifiers applied here)
	EventBus.weapon_spawned.emit(item)

	_throw_item(item, spawn_point.global_position, throw_target.global_position)

	print("ItemSpawningManager: crowd threw %s" % item.name)
	return item
