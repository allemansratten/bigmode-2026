extends Node
class_name OnEnemyKilledEffect

## Base class for effects that trigger when weapon kills an enemy
## Attach as child of item with WeaponBehaviour (melee or ranged)
## Examples: heal on kill, explosion on kill, spawn powerup, etc.

## Reference to the item (weapon)
var item: Node3D

## Reference to the weapon behaviour
var weapon: WeaponBehaviour


func _ready() -> void:
	item = get_parent() as Node3D
	if not item:
		push_error("OnEnemyKilledEffect must be child of Node3D item")
		return

	# Find weapon behaviour
	for child in item.get_children():
		if child is WeaponBehaviour:
			weapon = child
			break

	if not weapon:
		push_warning("OnEnemyKilledEffect: no WeaponBehaviour found on item %s" % item.name)


## VIRTUAL: Override to implement custom kill effect
## Called by WeaponBehaviour when weapon kills an enemy
## target: the enemy that was killed
func execute(target: Node3D) -> void:
	push_warning("OnEnemyKilledEffect.execute() not implemented for %s" % get_script().get_path())
