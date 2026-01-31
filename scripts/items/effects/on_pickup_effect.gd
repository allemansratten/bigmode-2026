extends Node
class_name OnPickupEffect

## Base class for effects that trigger when item is picked up
## Attach as child of item with PickupableBehaviour
## Examples: sound effects, particles, player buffs, UI notifications, etc.

## Reference to the item being picked up
var item: Node3D

## Reference to the pickupable behaviour
var pickupable: PickupableBehaviour


func _ready() -> void:
	item = _find_item_root()
	if not item:
		push_warning("OnPickupEffect: could not find item root (searched up from %s)" % get_parent().name if get_parent() else "unknown")
		return

	# Find pickupable behaviour
	for child in item.get_children():
		if child is PickupableBehaviour:
			pickupable = child
			break

	if not pickupable:
		push_warning("OnPickupEffect: no PickupableBehaviour found on item %s" % item.name)


## Traverse up the tree to find the item root (RigidBody3D or root Node3D)
func _find_item_root() -> Node3D:
	var current = get_parent()
	while current:
		if current is RigidBody3D:
			return current
		if current.get_parent() == null:
			return current as Node3D
		current = current.get_parent()
	return null


## VIRTUAL: Override to implement custom pickup effect
## Called by PickupableBehaviour when item is picked up
## picker: the entity that picked up the item (usually player)
func execute(_picker: Node3D) -> void:
	push_warning("OnPickupEffect.execute() not implemented for %s" % get_script().get_path())
