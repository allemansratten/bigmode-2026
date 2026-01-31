extends Node
class_name OnDestroyEffect

## Base class for effects that trigger when a weapon is destroyed
## Attach as child of item with WeaponBehaviour to add custom destruction effects
## Examples: spawn oil surface, create explosion, drop items, etc.

## Reference to the item being destroyed (set automatically by WeaponBehaviour)
var item: Node3D

## Reference to the weapon behaviour (set automatically)
var weapon: WeaponBehaviour


func _ready() -> void:
	item = get_parent() as Node3D
	if not item:
		push_error("OnDestroyEffect must be child of Node3D item")
		return

	# Find weapon behaviour
	for child in item.get_children():
		if child is WeaponBehaviour:
			weapon = child
			break

	if not weapon:
		push_warning("OnDestroyEffect: no WeaponBehaviour found on item %s" % item.name)


## VIRTUAL: Override to implement custom destruction effect
## Called by WeaponBehaviour when item is destroyed
func execute() -> void:
	push_warning("OnDestroyEffect.execute() not implemented for %s" % get_script().get_path())
