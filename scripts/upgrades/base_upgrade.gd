extends Node
class_name BaseUpgrade

## Base class for all upgrades
## Provides metadata (name, description, icon, tags) for UI and filtering
## Attach as root node of upgrade scenes in res://scenes/upgrades/

## Display name of the upgrade
@export var upgrade_name: String = "Unnamed Upgrade"

## Description shown in UI
@export_multiline var description: String = ""

## Icon for UI display
@export var icon: Texture2D

## Category tags for filtering (rarity, type, subtypes)
@export var categories: Array[UpgradeCategories.Category] = []

## Maximum stacks allowed (-1 = unlimited)
@export var max_stacks: int = -1


## Get the upgrade ID (filename without extension)
func get_upgrade_id() -> String:
	var scene_path = scene_file_path
	if scene_path.is_empty():
		return upgrade_name.to_snake_case()
	return scene_path.get_file().get_basename()


## Check if this upgrade has a specific category
func has_category(category: UpgradeCategories.Category) -> bool:
	return categories.has(category)


## Check if this upgrade matches any of the specified categories
func matches_any(filter: Array[UpgradeCategories.Category]) -> bool:
	return UpgradeCategories.has_any(categories, filter)


## Check if this upgrade matches all of the specified categories
func matches_all(filter: Array[UpgradeCategories.Category]) -> bool:
	return UpgradeCategories.has_all(categories, filter)


## Check if another stack can be added
func can_stack(current_stacks: int) -> bool:
	if max_stacks < 0:
		return true  # Unlimited
	return current_stacks < max_stacks


## Get the TriggerUpgrade component if present
func get_trigger_upgrade() -> TriggerUpgrade:
	for child in get_children():
		if child is TriggerUpgrade:
			return child
	return null


## Get the WeaponModifierUpgrade component if present
func get_weapon_modifier() -> WeaponModifierUpgrade:
	for child in get_children():
		if child is WeaponModifierUpgrade:
			return child
	return null
