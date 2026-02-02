class_name UpgradeCategories

## Global upgrade category/tag definitions
## Use for filtering which upgrades can be offered

## Upgrade category tags
enum Category {
	# Rarity tags
	COMMON = 0,
	UNCOMMON = 1,
	RARE = 2,
	EPIC = 3,

	# Type tags (broad categories)
	TRIGGER = 10,      # Event-driven effect
	WEAPON_MOD = 11,   # Weapon stat modifier
	ABILITY_MOD = 12,  # Player ability modifier

	# Trigger subtypes
	ON_KILL = 20,
	ON_DAMAGE = 21,
	ON_THROW = 22,
	ON_MOVEMENT = 23,
	ON_PICKUP = 24,

	# Weapon subtypes
	AFFECTS_MELEE = 30,
	AFFECTS_RANGED = 31,
	AFFECTS_ALL_WEAPONS = 32,
}

## Check if an upgrade has a specific category tag
static func has_category(categories: Array[Category], tag: Category) -> bool:
	return categories.has(tag)

## Check if an upgrade has any of the specified tags
static func has_any(categories: Array[Category], tags: Array[Category]) -> bool:
	for tag in tags:
		if categories.has(tag):
			return true
	return false

## Check if an upgrade has all of the specified tags
static func has_all(categories: Array[Category], tags: Array[Category]) -> bool:
	for tag in tags:
		if not categories.has(tag):
			return false
	return true

## Get all rarity tags from a category list
static func get_rarity_tags(categories: Array[Category]) -> Array[Category]:
	var rarity_tags: Array[Category] = []
	for cat in categories:
		if cat >= Category.COMMON and cat <= Category.EPIC:
			rarity_tags.append(cat)
	return rarity_tags

## Get all type tags from a category list
static func get_type_tags(categories: Array[Category]) -> Array[Category]:
	var type_tags: Array[Category] = []
	for cat in categories:
		if cat >= Category.TRIGGER and cat <= Category.ABILITY_MOD:
			type_tags.append(cat)
	return type_tags
