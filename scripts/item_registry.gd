extends Node

## Global item registry for spawnable items
## Discovers and caches items by category tags

const Categories = preload("res://scripts/item_categories.gd")

## All registered spawnable item scenes
var all_items: Array[PackedScene] = []

## Cache: category -> array of matching items
var items_by_category: Dictionary = {}


func _ready() -> void:
	_register_all_items()
	_build_category_cache()


## Register all spawnable item scenes (auto-discover from items directory)
func _register_all_items() -> void:
	all_items.clear()

	# Scan items directory for all .tscn files
	var items_dir = "res://scenes/items/"
	var dir = DirAccess.open(items_dir)

	if not dir:
		push_error("ItemRegistry: failed to open items directory: %s" % items_dir)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		# Only process .tscn files
		if not dir.current_is_dir() and file_name.ends_with(".tscn"):
			var item_path = items_dir + file_name
			var item_scene = load(item_path) as PackedScene

			if item_scene:
				# Check if it has SpawnableBehaviour
				if _has_spawnable_behaviour(item_scene):
					all_items.append(item_scene)
					print("ItemRegistry: registered %s" % file_name)
				else:
					print("ItemRegistry: skipped %s (no SpawnableBehaviour)" % file_name)
			else:
				push_warning("ItemRegistry: failed to load %s" % item_path)

		file_name = dir.get_next()

	dir.list_dir_end()

	print("ItemRegistry: registered %d items total" % all_items.size())


## Build cache of items organized by category
func _build_category_cache() -> void:
	items_by_category.clear()

	for item_scene in all_items:
		var spawnable = _get_spawnable_behaviour(item_scene)
		if not spawnable:
			continue

		# Add this item to cache for each of its categories
		for category in spawnable.categories:
			if not items_by_category.has(category):
				items_by_category[category] = []
			items_by_category[category].append(item_scene)

	print("ItemRegistry: built category cache for %d categories" % items_by_category.size())


## Get all items that match ANY of the given categories
func get_items_matching_any(categories: Array[Categories.Category]) -> Array[PackedScene]:
	var matching_items: Array[PackedScene] = []
	var seen: Dictionary = {}  # Track unique items

	for category in categories:
		if items_by_category.has(category):
			for item in items_by_category[category]:
				if not seen.has(item):
					seen[item] = true
					matching_items.append(item)

	return matching_items


## Get all items that match ALL of the given categories
func get_items_matching_all(categories: Array[Categories.Category]) -> Array[PackedScene]:
	var matching_items: Array[PackedScene] = []

	for item_scene in all_items:
		var spawnable = _get_spawnable_behaviour(item_scene)
		if spawnable and spawnable.matches_all(categories):
			matching_items.append(item_scene)

	return matching_items


## Helper: Check if item scene has SpawnableBehaviour
func _has_spawnable_behaviour(item_scene: PackedScene) -> bool:
	var temp_item = item_scene.instantiate()
	var has_spawnable = temp_item.has_node("SpawnableBehaviour")
	temp_item.queue_free()
	return has_spawnable


## Helper: Get SpawnableBehaviour from an item scene (temporary instantiation)
func _get_spawnable_behaviour(item_scene: PackedScene) -> SpawnableBehaviour:
	var temp_item = item_scene.instantiate()
	var spawnable = temp_item.get_node_or_null("SpawnableBehaviour") as SpawnableBehaviour

	temp_item.queue_free()
	return spawnable
