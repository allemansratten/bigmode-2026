extends UpgradeEffect
class_name CrowdThrowEffect

## Requests the crowd to throw an item matching specified categories
## Emits EventBus.crowd_throw_requested for ItemSpawningManager to handle

const Categories = preload("res://scripts/core/item_categories.gd")

## Categories the thrown item must match (uses matches_any)
## Empty = use room's default categories
@export var item_categories: Array[Categories.Category] = []


func execute(_context: Dictionary, _stacks: int = 1) -> void:
	# Convert to regular Array for signal compatibility
	var categories_array: Array = []
	for cat in item_categories:
		categories_array.append(cat)

	EventBus.crowd_throw_requested.emit(categories_array)
	print("CrowdThrowEffect: requested crowd throw with categories %s" % [item_categories])
