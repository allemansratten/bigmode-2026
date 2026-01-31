class_name EffectUtils

## Utility functions for finding and working with effect components
## Used by behavior scripts to locate effects in item scene trees

## Find effects recursively, including in container nodes
## Searches direct children first, then recurses into plain Node containers
## Skips physics/spatial nodes (Node3D, Area3D, CollisionShape3D) to avoid unnecessary traversal
static func find_effects_recursive(node: Node, effect_type) -> Array:
	var effects = []
	for child in node.get_children():
		if is_instance_of(child, effect_type):
			effects.append(child)
		# Recurse into plain Node containers (skip physics/area nodes)
		elif child is Node and not (child is Node3D or child is Area3D or child is CollisionShape3D):
			effects.append_array(find_effects_recursive(child, effect_type))
	return effects


## Find and execute effects in one call
## Searches recursively for effects of the given type and executes them with provided arguments
## Example: execute_effects(item, OnEnemyKilledEffect, [target])
static func execute_effects(node: Node, effect_type, args: Array = []) -> void:
	for effect in find_effects_recursive(node, effect_type):
		if args.is_empty():
			effect.execute()
		else:
			effect.callv("execute", args)
