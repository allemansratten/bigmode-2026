class_name ThrowableBehaviour
extends Node

## Composition behaviour: makes the parent item throwable.
## Attach this script to a Node; the parent must be a RigidBody3D and have PickupableBehaviour.
## Call throw() when the holder releases (e.g. from player input).

const PickupableBehaviourScript := preload("res://scripts/items/pickupable_behaviour.gd")

## Impulse force applied when thrown (tune per item)
@export var throw_force: float = 12.0
## Optional: upward bias (0 = horizontal, 1 = mostly up)
@export var throw_up_bias: float = 0.2

var _pickupable: Node  # PickupableBehaviour

func _ready() -> void:
	_pickupable = get_parent().get_node_or_null("PickupableBehaviour")
	if _pickupable == null:
		for c in get_parent().get_children():
			if c.get_script() == PickupableBehaviourScript:
				_pickupable = c
				break
	if _pickupable == null:
		push_warning("ThrowableBehaviour: no PickupableBehaviour found on parent %s" % get_parent().name)


## Call when the holder wants to throw. direction should be normalized (e.g. camera forward).
## world_root: node to reparent the item to when thrown (e.g. get_tree().current_scene or "Items").
func throw(direction: Vector3, world_root: Node) -> void:
	var item: Node = get_parent()
	if not item is RigidBody3D:
		return
	var rb: RigidBody3D = item as RigidBody3D
	var old_global_pos: Vector3 = rb.global_position
	item.reparent(world_root)
	rb.global_position = old_global_pos
	rb.freeze = false
	if _pickupable:
		_pickupable.clear_holder()
	# Throw direction: blend horizontal direction with upward bias
	var up := Vector3.UP
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() > 0.01:
		flat = flat.normalized()
	var throw_dir := (flat * (1.0 - throw_up_bias) + up * throw_up_bias).normalized()
	rb.apply_central_impulse(throw_dir * throw_force)
