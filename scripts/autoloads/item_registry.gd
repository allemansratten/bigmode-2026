extends Node

## Global item registry for spawnable items
## Discovers and caches items by category tags

const Categories = preload("res://scripts/core/item_categories.gd")

## All registered spawnable item scenes
var all_items: Array[PackedScene] = []

## Cache: category -> array of matching items
var items_by_category: Dictionary = {}


func _ready() -> void:
	_register_all_items()
	_build_category_cache()


## Static manifest of item paths (required for web export - DirAccess doesn't work)
## Add new items here when creating them
const ITEM_PATHS: Array[String] = [
	"res://scenes/items/Brick.tscn",
	"res://scenes/items/Bludgeon.tscn",
	"res://scenes/items/Crate.tscn",
	"res://scenes/items/Crossbow.tscn",
	"res://scenes/items/Dagger.tscn",
	"res://scenes/items/DoubleCrossbow.tscn",
	"res://scenes/items/Mace.tscn",
	"res://scenes/items/OilFlask.tscn",
	"res://scenes/items/TeleportBook.tscn",
]


## Register all spawnable item scenes from static manifest
func _register_all_items() -> void:
	all_items.clear()

	for item_path in ITEM_PATHS:
		var item_scene = load(item_path) as PackedScene

		if item_scene:
			# Check if it has SpawnableBehaviour
			if _has_spawnable_behaviour(item_scene):
				all_items.append(item_scene)
				print("ItemRegistry: registered %s" % item_path.get_file())
			else:
				print("ItemRegistry: skipped %s (no SpawnableBehaviour)" % item_path.get_file())
		else:
			push_warning("ItemRegistry: failed to load %s" % item_path)

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


## Group a list of items by their rarity tag
## Returns Dictionary: {Category.COMMON: [PackedScene], Category.UNCOMMON: [...], ...}
## Items without a rarity tag are placed in COMMON by default
func group_items_by_rarity(items: Array[PackedScene]) -> Dictionary:
	var grouped: Dictionary = {
		Categories.Category.COMMON: [],
		Categories.Category.UNCOMMON: [],
		Categories.Category.RARE: [],
		Categories.Category.EPIC: [],
	}

	for item_scene in items:
		var spawnable = _get_spawnable_behaviour(item_scene)
		if not spawnable:
			continue

		var rarity_tags = Categories.get_rarity_tags(spawnable.categories)
		if rarity_tags.is_empty():
			# Default to COMMON if no rarity specified
			grouped[Categories.Category.COMMON].append(item_scene)
		else:
			# Use the highest rarity tag if multiple exist
			var highest_rarity = rarity_tags.max()
			grouped[highest_rarity].append(item_scene)

	return grouped


## Filter out rarity tags from a category array, returning only type/specific tags
func filter_non_rarity_categories(categories: Array[Categories.Category]) -> Array[Categories.Category]:
	var filtered: Array[Categories.Category] = []
	for cat in categories:
		if cat > Categories.Category.EPIC:  # Rarity tags are 0-3
			filtered.append(cat)
	return filtered


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
