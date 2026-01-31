extends Node
class_name OnEnemyHitEffect

## Base class for effects that trigger when weapon hits an enemy
## Attach as child of item with WeaponBehaviour (melee or ranged)
## Examples: lifesteal, status effects (poison, burn), extra damage, etc.

## Reference to the item (weapon)
var item: Node3D

## Reference to the weapon behaviour
var weapon: WeaponBehaviour


func _ready() -> void:
	item = _find_item_root()
	if not item:
		push_warning("OnEnemyHitEffect: could not find item root (searched up from %s)" % get_parent().name if get_parent() else "unknown")
		return

	# Find weapon behaviour
	for child in item.get_children():
		if child is WeaponBehaviour:
			weapon = child
			break

	if not weapon:
		push_warning("OnEnemyHitEffect: no WeaponBehaviour found on item %s" % item.name)


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


## VIRTUAL: Override to implement custom hit effect
## Called by WeaponBehaviour when weapon hits an enemy
## target: the enemy that was hit
## damage_dealt: amount of damage that was dealt
func execute(_target: Node3D, _damage_dealt: float) -> void:
	push_warning("OnEnemyHitEffect.execute() not implemented for %s" % get_script().get_path())
