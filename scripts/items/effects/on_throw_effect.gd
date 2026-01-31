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
	item = get_parent() as Node3D
	if not item:
		push_error("OnThrowEffect must be child of Node3D item")
		return

	# Find throwable behaviour
	for child in item.get_children():
		if child is ThrowableBehaviour:
			throwable = child
			break

	if not throwable:
		push_warning("OnThrowEffect: no ThrowableBehaviour found on item %s" % item.name)


## VIRTUAL: Override to implement custom throw effect
## Called by ThrowableBehaviour when item is thrown
## direction: normalized throw direction
## force: throw force magnitude
## from_crowd: true if thrown by crowd spawning system
func execute(_direction: Vector3, _force: float, _from_crowd: bool) -> void:
	push_warning("OnThrowEffect.execute() not implemented for %s" % get_script().get_path())
