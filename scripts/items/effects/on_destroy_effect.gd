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
	item = _find_item_root()
	if not item:
		push_warning("OnDestroyEffect: could not find item root (searched up from %s)" % get_parent().name if get_parent() else "unknown")
		return

	# Find weapon behaviour
	for child in item.get_children():
		if child is WeaponBehaviour:
			weapon = child
			break

	if not weapon:
		push_warning("OnDestroyEffect: no WeaponBehaviour found on item %s" % item.name)


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


## VIRTUAL: Override to implement custom destruction effect
## Called by WeaponBehaviour when item is destroyed
func execute() -> void:
	push_warning("OnDestroyEffect.execute() not implemented for %s" % get_script().get_path())
