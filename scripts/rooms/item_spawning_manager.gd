extends Node
class_name ItemSpawningManager

## Manages item spawning for a room
## Attach to room root; spawn items from spawn points to throw targets

const Categories = preload("res://scripts/core/item_categories.gd")

## Tags that items must match to spawn in this room (uses matches_any)
@export var allowed_categories: Array[Categories.Category] = []

## Throw force magnitude
@export var throw_force: float = 10.0

## Throw arc height multiplier (0 = direct, higher = more arc)
@export var arc_height: float = 1.0

## Reference to the room node
var room: Node3D

## Cached spawn points
var spawn_points: Array[ItemSpawnPoint] = []

## Cached throw targets
var throw_targets: Array[ItemThrowTarget] = []

## Cached valid items (filtered by allowed categories)
var valid_items: Array[PackedScene] = []


func _ready() -> void:
	room = get_parent() as Node3D
	if not room:
		push_error("ItemSpawningManager must be child of room Node3D")
		return

	_cache_spawn_nodes()
	_cache_valid_items()


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

	# Query ItemRegistry for items matching our categories
	valid_items = ItemRegistry.get_items_matching_any(allowed_categories)

	if valid_items.is_empty():
		push_error("ItemSpawningManager: no items match allowed categories")

	print("ItemSpawningManager: %d items match allowed categories %s" % [valid_items.size(), allowed_categories])


## Spawn a random item matching room's allowed categories
func spawn_item() -> Node3D:
	# Pick random item, spawn point, and target
	var item_scene = valid_items.pick_random()
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
