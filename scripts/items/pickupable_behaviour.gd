class_name PickupableBehaviour
extends Area3D


## Composition behaviour: makes the parent node pickupable by the player.
## Attach this script to an Area3D; the parent is the "item" (e.g. RigidBody3D).
## Add the parent to group "pickupable" so the player can find it.

signal picked_up(by: Node)
signal dropped()
signal deactivated()  ## Emitted when item becomes inactive in inventory (but still held)
signal activated()  ## Emitted when item becomes active again in inventory

## Optional: node path from holder to the container where the item is reparented (e.g. "HoldPoint")
@export var holder_attach_path: NodePath = ^"HoldPoint"

var _holder: Node3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# So the player can find items by group and get the root item
	var item := get_parent()
	if not item.is_in_group("pickupable"):
		item.add_to_group("pickupable")


func _on_body_entered(_body: Node3D) -> void:
	# Optional: only react to player (CharacterBody3D named "Player" or in group "player")
	pass


func _on_body_exited(_body: Node3D) -> void:
	pass


## Call this from the player when interact is pressed and this item is the chosen target.
## Returns true if the pickup succeeded.
func try_pick_up(by: Node3D) -> bool:
	var item: Node3D = get_parent()
	if not item is RigidBody3D:
		push_warning("PickupableBehaviour: parent %s is not a RigidBody3D" % item.name)
		return false
	var rb: RigidBody3D = item as RigidBody3D
	if _holder != null:
		return false
	var attach: Node3D = by.get_node_or_null(holder_attach_path) if holder_attach_path else by
	if attach == null:
		attach = by
	# Reparent item under holder and freeze so it doesn't fall
	item.reparent(attach)
	item.position = Vector3.ZERO
	item.rotation = Vector3.ZERO
	rb.freeze = true
	_set_item_collision(item, false)
	_holder = by

	# Execute OnPickupEffect components
	EffectUtils.execute_effects(item, OnPickupEffect, [by])

	picked_up.emit(by)

	# Emit global event for upgrade system
	EventBus.item_picked_up.emit(item, by)

	return true


## Called when the item is thrown or dropped; clears holder reference and re-enables collision.
func clear_holder() -> void:
	var item: Node3D = get_parent()
	_set_item_collision(item, true)
	_holder = null
	dropped.emit()


## Enable or disable all CollisionShape3D nodes under root (item and its descendants).
func _set_item_collision(item: Node, enabled: bool) -> void:
	if item is CollisionShape3D:
		(item as CollisionShape3D).disabled = not enabled
	for child in item.get_children():
		_set_item_collision(child, enabled)


func get_holder() -> Node3D:
	return _holder


func is_held() -> bool:
	return _holder != null


## Called by inventory when item becomes inactive (switched to another slot)
func deactivate() -> void:
	deactivated.emit()


## Called by inventory when item becomes active again
func activate() -> void:
	activated.emit()
