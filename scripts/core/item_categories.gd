class_name ItemCategories

## Global item category/tag definitions
## Use for filtering which items can spawn in rooms

## Item category tags
enum Category {
	# Rarity tags
	COMMON = 0,
	UNCOMMON = 1,
	RARE = 2,
	EPIC = 3,

	# Type tags (broad categories)
	WEAPON = 10,
	MOVEMENT = 11,
	SPELL = 12,
	CONSUMABLE = 13,

	# Specific tags (detailed classification)
	MELEE = 20,
	RANGED = 21,
	PROJECTILE = 22,
	AREA = 23,
	THROWN = 24,
}

## Check if an item has a specific category tag
static func has_category(categories: Array[Category], tag: Category) -> bool:
	return categories.has(tag)

## Check if an item has any of the specified tags
static func has_any(categories: Array[Category], tags: Array[Category]) -> bool:
	for tag in tags:
		if categories.has(tag):
			return true
	return false

## Check if an item has all of the specified tags
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
		if cat >= Category.WEAPON and cat <= Category.CONSUMABLE:
			type_tags.append(cat)
	return type_tags

## Get all specific tags from a category list
static func get_specific_tags(categories: Array[Category]) -> Array[Category]:
	var specific_tags: Array[Category] = []
	for cat in categories:
		if cat >= Category.MELEE and cat <= Category.THROWN:
			specific_tags.append(cat)
	return specific_tags
