extends Node
class_name OnThrowEffect

## Base class for effects that trigger when an item is thrown
## Attach as child of item with ThrowableBehaviour
## Examples: trail particles, sound effects, buffs, etc.

## Reference to the item being thrown
var item: Node3D

## Reference to the throwable behaviour
var throwable: ThrowableBehaviour


func _ready() -> void:
	item = _find_item_root()
	if not item:
		push_warning("OnThrowEffect: could not find item root (searched up from %s)" % get_parent().name if get_parent() else "unknown")
		return

	# Find throwable behaviour
	for child in item.get_children():
		if child is ThrowableBehaviour:
			throwable = child
			break

	if not throwable:
		push_warning("OnThrowEffect: no ThrowableBehaviour found on item %s" % item.name)


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


## VIRTUAL: Override to implement custom throw effect
## Called by ThrowableBehaviour when item is thrown
## direction: normalized throw direction
## force: throw force magnitude
## from_crowd: true if thrown by crowd spawning system
func execute(_direction: Vector3, _force: float, _from_crowd: bool) -> void:
	push_warning("OnThrowEffect.execute() not implemented for %s" % get_script().get_path())
