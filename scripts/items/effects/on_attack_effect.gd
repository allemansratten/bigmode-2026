extends Node
class_name OnAttackEffect

## Base class for effects that trigger when weapon attacks
## Attach as child of item with WeaponBehaviour
## Examples: attack particles, sound effects, screen shake, etc.

## Reference to the item (weapon)
var item: Node3D

## Reference to the weapon behaviour
var weapon: WeaponBehaviour


func _ready() -> void:
	item = get_parent() as Node3D
	if not item:
		push_error("OnAttackEffect must be child of Node3D item")
		return

	# Find weapon behaviour
	for child in item.get_children():
		if child is WeaponBehaviour:
			weapon = child
			break

	if not weapon:
		push_warning("OnAttackEffect: no WeaponBehaviour found on item %s" % item.name)


## VIRTUAL: Override to implement custom attack effect
## Called by WeaponBehaviour when weapon performs an attack
func execute() -> void:
	push_warning("OnAttackEffect.execute() not implemented for %s" % get_script().get_path())
