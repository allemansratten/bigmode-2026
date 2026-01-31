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
	item = get_parent() as Node3D
	if not item:
		push_error("OnPickupEffect must be child of Node3D item")
		return

	# Find pickupable behaviour
	for child in item.get_children():
		if child is PickupableBehaviour:
			pickupable = child
			break

	if not pickupable:
		push_warning("OnPickupEffect: no PickupableBehaviour found on item %s" % item.name)


## VIRTUAL: Override to implement custom pickup effect
## Called by PickupableBehaviour when item is picked up
## picker: the entity that picked up the item (usually player)
func execute(_picker: Node3D) -> void:
	push_warning("OnPickupEffect.execute() not implemented for %s" % get_script().get_path())
