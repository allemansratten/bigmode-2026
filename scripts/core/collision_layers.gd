class_name CollisionLayers

## Global collision layer definitions
## Use static functions and enum directly in code

## Collision layer bit positions (0-indexed)
enum Layer {
	ENVIRONMENT = 0,  	# Layer 0: World geometry, static objects
	PLAYER = 1,  	 	# Layer 1: Player character
	ENEMY = 2,    		# Layer 2: Enemy characters (e.g. enemies, NPCs, etc.)
	ITEM = 3,     		# Layer 3: Items (e.g. weapons, powerups) (pickupable)
	PLAYER_INTERACTION = 4,  # Layer 4: Player interaction body (for pushing items)
}

## Get the layer mask value for a specific layer
static func get_mask(layer: Layer) -> int:
	return 1 << layer

## Get a combined mask for multiple layers
static func get_combined_mask(layers: Array[Layer]) -> int:
	var mask = 0
	for layer in layers:
		mask |= get_mask(layer)
	return mask
