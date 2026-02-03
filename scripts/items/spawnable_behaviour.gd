extends Node
class_name SpawnableBehaviour

## Marks an item as spawnable and defines its category tags
## Add this as a child node to any spawnable item (weapon, powerup, etc.)

const Categories = preload("res://scripts/core/item_categories.gd")
const ICON_DIR = "res://resources/icons/items/"

## Category tags for this item (rarity, type, specific)
@export var categories: Array[Categories.Category] = []

## Reference to the parent item (set automatically)
var item: Node3D

## Custom icon texture (auto-loaded from screenshot if not set)
@export var custom_icon: Texture2D

## Cached icon after auto-loading
var _loaded_icon: Texture2D

func _ready() -> void:
	item = get_parent() as Node3D
	if not item:
		push_error("SpawnableBehaviour must be child of a Node3D item")
		return

	# Auto-load icon from generated screenshots if custom_icon not set
	if not custom_icon:
		_auto_load_icon()


## Check if this item matches any of the given tags
func matches_any(tags: Array[Categories.Category]) -> bool:
	return Categories.has_any(categories, tags)


## Check if this item matches all of the given tags
func matches_all(tags: Array[Categories.Category]) -> bool:
	return Categories.has_all(categories, tags)


## Get a string representation of this item's categories (for debugging)
func get_category_string() -> String:
	var tags: Array[String] = []
	for cat in categories:
		tags.append(Categories.Category.keys()[cat])
	return ", ".join(tags)

func get_icon() -> Texture2D:
	if custom_icon:
		return custom_icon
	return _loaded_icon


## Auto-load icon from generated screenshot based on item scene name
func _auto_load_icon() -> void:
	if not item:
		return

	# Get item's scene file name without extension
	var scene_path = item.scene_file_path
	if scene_path.is_empty():
		push_warning("SpawnableBehaviour: Item %s has no scene_file_path, cannot auto-load icon" % item.name)
		return

	# Extract filename without extension (e.g., "Sword.tscn" -> "Sword")
	var scene_filename = scene_path.get_file().get_basename()

	# Construct icon path (e.g., "res://resources/icons/items/Sword.png")
	var icon_path = ICON_DIR + scene_filename + ".png"

	# Try to load the icon
	if ResourceLoader.exists(icon_path):
		_loaded_icon = load(icon_path) as Texture2D
		if _loaded_icon:
			print("SpawnableBehaviour: Auto-loaded icon for %s from %s" % [item.name, icon_path])
		else:
			push_error("SpawnableBehaviour: Failed to load icon for %s at %s" % [item.name, icon_path])
	else:
		push_error("SpawnableBehaviour: Icon not found for %s at %s. Run ItemIconGenerator tool to generate screenshots." % [item.name, icon_path])
