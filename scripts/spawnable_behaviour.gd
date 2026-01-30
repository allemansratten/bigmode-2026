extends Node
class_name SpawnableBehaviour

## Marks an item as spawnable and defines its category tags
## Add this as a child node to any spawnable item (weapon, powerup, etc.)

const Categories = preload("res://scripts/item_categories.gd")

## Category tags for this item (rarity, type, specific)
@export var categories: Array[Categories.Category] = []

## Reference to the parent item (set automatically)
var item: Node3D


func _ready() -> void:
	item = get_parent() as Node3D
	if not item:
		push_error("SpawnableBehaviour must be child of a Node3D item")


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
