extends Node
class_name OnThrowLandedEffect

## Base class for effects that trigger when a thrown item lands
## Attach as child of item with ThrowableBehaviour
## Examples: impact particles, ground effects, sound effects, etc.

## Reference to the item that landed
var item: Node3D

## Reference to the throwable behaviour
var throwable: ThrowableBehaviour


func _ready() -> void:
	item = _find_item_root()
	if not item:
		push_warning("OnThrowLandedEffect: could not find item root (searched up from %s)" % get_parent().name if get_parent() else "unknown")
		return

	# Find throwable behaviour
	for child in item.get_children():
		if child is ThrowableBehaviour:
			throwable = child
			break

	if not throwable:
		push_warning("OnThrowLandedEffect: no ThrowableBehaviour found on item %s" % item.name)


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


## VIRTUAL: Override to implement custom landing effect
## Called by ThrowableBehaviour when thrown item lands (first collision only)
## collision_body: the body that was hit
func execute(_collision_body: Node) -> void:
	push_warning("OnThrowLandedEffect.execute() not implemented for %s" % get_script().get_path())
