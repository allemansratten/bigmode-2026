extends Node
class_name WeaponModifierUpgrade

## Component for weapon stat modifier upgrades
## Defines which weapons to affect and what stats to modify
## Attach as child of BaseUpgrade

const Categories = preload("res://scripts/core/item_categories.gd")

## Filter for which weapons this upgrade affects
## Uses ItemCategories (MELEE, RANGED, etc.)
## Empty array = affects all weapons
@export var weapon_filter: Array[Categories.Category] = []

## List of stat modifications to apply
@export var stat_modifiers: Array[StatModifier] = []

## Reference to parent BaseUpgrade
var base_upgrade: BaseUpgrade


func _ready() -> void:
	base_upgrade = get_parent() as BaseUpgrade
	if not base_upgrade:
		push_warning("WeaponModifierUpgrade: must be child of BaseUpgrade")


## Check if a weapon matches this upgrade's filter
func matches_weapon(weapon: Node3D) -> bool:
	# If no filter, match all weapons
	if weapon_filter.is_empty():
		return true

	# Check SpawnableBehaviour for category tags
	var spawnable = weapon.get_node_or_null("SpawnableBehaviour") as SpawnableBehaviour
	if not spawnable:
		return false

	return spawnable.matches_any(weapon_filter)


## Apply all stat modifiers to a weapon
## stacks: number of times the upgrade has been acquired
func apply_to_weapon(weapon: Node3D, stacks: int = 1) -> void:
	# Find weapon behaviour
	var weapon_behaviour = _find_weapon_behaviour(weapon)
	if not weapon_behaviour:
		return

	# Apply each modifier
	for modifier in stat_modifiers:
		modifier.apply(weapon_behaviour, stacks)

	if base_upgrade:
		print("WeaponModifierUpgrade: Applied %s (x%d) to %s" % [
			base_upgrade.upgrade_name, stacks, weapon.name
		])


## Find WeaponBehaviour (or subclass) on the weapon
func _find_weapon_behaviour(weapon: Node3D) -> WeaponBehaviour:
	for child in weapon.get_children():
		if child is WeaponBehaviour:
			return child
	return null
