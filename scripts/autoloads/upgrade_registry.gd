extends Node

## Global upgrade registry
## Discovers and caches upgrades from res://scenes/upgrades/
## Mirrors ItemRegistry pattern

## All registered upgrade scenes
var all_upgrades: Array[PackedScene] = []

## Map of upgrade_id -> PackedScene
var upgrades_by_id: Dictionary = {}

## Cache: category -> array of matching upgrade IDs
var upgrades_by_category: Dictionary = {}

## Static manifest of upgrade paths (required for web export - DirAccess doesn't work)
## Add new upgrades here when creating them
const UPGRADE_PATHS: Array[String] = [
	"res://scenes/upgrades/BrickBreakCrowdThrow.tscn",
	"res://scenes/upgrades/BrickBreakExplosion.tscn",
	"res://scenes/upgrades/BrickMaker.tscn",
	"res://scenes/upgrades/DashDamage.tscn",
	"res://scenes/upgrades/FlaskShower.tscn",
	"res://scenes/upgrades/HealOnKill.tscn",
	"res://scenes/upgrades/IceTeleport.tscn",
	"res://scenes/upgrades/KillMilestoneExcitement.tscn",
	"res://scenes/upgrades/KillMilestoneHeal.tscn",
	"res://scenes/upgrades/MeleeCrowdThrow.tscn",
	"res://scenes/upgrades/MeleeDurability.tscn",
	"res://scenes/upgrades/RangedAmmoBonus.tscn",
	"res://scenes/upgrades/RangedAutoShoot.tscn",
]


func _ready() -> void:
	_register_all_upgrades()
	_build_category_cache()


## Register all upgrade scenes from static manifest
func _register_all_upgrades() -> void:
	all_upgrades.clear()
	upgrades_by_id.clear()

	for upgrade_path in UPGRADE_PATHS:
		var upgrade_scene = load(upgrade_path) as PackedScene

		if upgrade_scene:
			# Check if it has BaseUpgrade
			if _has_base_upgrade(upgrade_scene):
				var upgrade_id = upgrade_path.get_file().get_basename()
				all_upgrades.append(upgrade_scene)
				upgrades_by_id[upgrade_id] = upgrade_scene
				print("UpgradeRegistry: registered %s" % upgrade_path.get_file())
			else:
				print("UpgradeRegistry: skipped %s (no BaseUpgrade root)" % upgrade_path.get_file())
		else:
			push_warning("UpgradeRegistry: failed to load %s" % upgrade_path)

	print("UpgradeRegistry: registered %d upgrades total" % all_upgrades.size())


## Build cache of upgrades organized by category
func _build_category_cache() -> void:
	upgrades_by_category.clear()

	for upgrade_id in upgrades_by_id:
		var upgrade_scene = upgrades_by_id[upgrade_id]
		var base_upgrade = _get_base_upgrade(upgrade_scene)
		if not base_upgrade:
			continue

		# Add this upgrade to cache for each of its categories
		for category in base_upgrade.categories:
			if not upgrades_by_category.has(category):
				upgrades_by_category[category] = []
			upgrades_by_category[category].append(upgrade_id)

	print("UpgradeRegistry: built category cache for %d categories" % upgrades_by_category.size())


## Get upgrade scene by ID
func get_upgrade(upgrade_id: String) -> PackedScene:
	return upgrades_by_id.get(upgrade_id, null)


## Get all registered upgrade IDs
func get_all_upgrade_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in upgrades_by_id.keys():
		ids.append(id)
	return ids


## Get random upgrades (for pick-from-N selection)
## filter: optional category filter (empty = all upgrades)
## exclude: upgrade IDs to exclude (e.g., already at max stacks)
func get_random_upgrades(count: int, filter: Array[UpgradeCategories.Category] = [], exclude: Array[String] = []) -> Array[String]:
	var pool: Array[String] = []

	if filter.is_empty():
		# All upgrades
		pool = get_all_upgrade_ids()
	else:
		# Filter by category
		pool = get_upgrades_matching_any(filter)

	# Remove excluded
	for excluded_id in exclude:
		pool.erase(excluded_id)

	# Shuffle and take count
	pool.shuffle()
	var result: Array[String] = []
	for i in mini(count, pool.size()):
		result.append(pool[i])

	return result


## Get upgrades matching any of the specified categories
func get_upgrades_matching_any(categories: Array[UpgradeCategories.Category]) -> Array[String]:
	var matching: Array[String] = []
	var seen: Dictionary = {}

	for category in categories:
		if upgrades_by_category.has(category):
			for upgrade_id in upgrades_by_category[category]:
				if not seen.has(upgrade_id):
					seen[upgrade_id] = true
					matching.append(upgrade_id)

	return matching


## Get upgrades matching all of the specified categories
func get_upgrades_matching_all(categories: Array[UpgradeCategories.Category]) -> Array[String]:
	var matching: Array[String] = []

	for upgrade_id in upgrades_by_id:
		var upgrade_scene = upgrades_by_id[upgrade_id]
		var base_upgrade = _get_base_upgrade(upgrade_scene)
		if base_upgrade and base_upgrade.matches_all(categories):
			matching.append(upgrade_id)

	return matching


## Helper: Check if upgrade scene has BaseUpgrade as root
func _has_base_upgrade(upgrade_scene: PackedScene) -> bool:
	var temp = upgrade_scene.instantiate()
	var has_base = temp is BaseUpgrade
	temp.queue_free()
	return has_base


## Helper: Get BaseUpgrade from an upgrade scene (temporary instantiation)
func _get_base_upgrade(upgrade_scene: PackedScene) -> BaseUpgrade:
	var temp = upgrade_scene.instantiate()
	var base = temp as BaseUpgrade
	temp.queue_free()
	return base
