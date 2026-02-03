extends UpgradeEffect
class_name IncreaseExcitementEffect

## Increases crowd excitement level
## Finds CrowdManager in the scene and calls increase_excitement()

## Amount of excitement to add
@export var excitement_amount: float = 10.0

## Whether stacks multiply the excitement amount
@export var scales_with_stacks: bool = true


func execute(_context: Dictionary, stacks: int = 1) -> void:
	var amount = excitement_amount
	if scales_with_stacks:
		amount *= stacks

	# Find CrowdManager in the scene
	var crowd_manager = get_tree().get_first_node_in_group("crowd_manager")
	if not crowd_manager:
		# Try finding by class name
		for node in get_tree().get_nodes_in_group(""):
			if node is CrowdManager:
				crowd_manager = node
				break

	if crowd_manager and crowd_manager.has_method("increase_excitement"):
		crowd_manager.increase_excitement(amount)
		print("IncreaseExcitementEffect: increased excitement by %.1f" % amount)
	else:
		push_warning("IncreaseExcitementEffect: CrowdManager not found")
