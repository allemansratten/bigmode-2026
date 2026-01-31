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
	item = get_parent() as Node3D
	if not item:
		push_error("OnThrowLandedEffect must be child of Node3D item")
		return

	# Find throwable behaviour
	for child in item.get_children():
		if child is ThrowableBehaviour:
			throwable = child
			break

	if not throwable:
		push_warning("OnThrowLandedEffect: no ThrowableBehaviour found on item %s" % item.name)


## VIRTUAL: Override to implement custom landing effect
## Called by ThrowableBehaviour when thrown item lands (first collision only)
## collision_body: the body that was hit
func execute(_collision_body: Node) -> void:
	push_warning("OnThrowLandedEffect.execute() not implemented for %s" % get_script().get_path())
