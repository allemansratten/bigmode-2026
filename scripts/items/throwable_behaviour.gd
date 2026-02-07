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
## Durability damage when thrown item lands
@export var throw_durability_cost: float = 2.0
## Damage dealt to enemies on collision when thrown
@export var throw_collision_damage: float = 10.0

signal thrown(direction: Vector3, force: float, from_crowd: bool)
signal throw_landed(collision: KinematicCollision3D)

var _pickupable: Node  # PickupableBehaviour
var _has_landed: bool = false
var _is_from_crowd: bool = false
var _item: RigidBody3D = null
var _weapon_behaviour: WeaponBehaviour = null
var _original_collision_mask: int = 0

# Pending throw state - set when throw() is called, executed on throw_frame
var _pending_throw_direction: Vector3
var _pending_throw_world_root: Node
var _pending_throw_from_crowd: bool = false
var _throw_animation_controller: AnimationController = null

func _ready() -> void:
	_pickupable = get_parent().get_node_or_null("PickupableBehaviour")
	if _pickupable == null:
		for c in get_parent().get_children():
			if c.get_script() == PickupableBehaviourScript:
				_pickupable = c
				break
	if _pickupable == null:
		push_warning("ThrowableBehaviour: no PickupableBehaviour found on parent %s" % get_parent().name)

	# Store item reference
	_item = get_parent() as RigidBody3D
	if _item:
		# Ensure contact monitoring is enabled for body_entered signal
		if not _item.contact_monitor:
			_item.contact_monitor = true
		if _item.max_contacts_reported < 1:
			_item.max_contacts_reported = 4
		_item.body_entered.connect(_on_body_entered)
		# Look for WeaponBehaviour (including subclasses)
		for child in _item.get_children():
			if child is WeaponBehaviour:
				_weapon_behaviour = child
				break


## Call when the holder wants to throw. direction should be normalized (e.g. camera forward).
## world_root: node to reparent the item to when thrown (e.g. get_tree().current_scene or "Items").
## from_crowd: if true, this throw is from crowd spawning and won't cost durability.
func throw(direction: Vector3, world_root: Node, from_crowd: bool = false) -> void:
	var item: Node = get_parent()
	if not item is RigidBody3D:
		return
	
	# Store throw parameters for execution on throw_frame
	_pending_throw_direction = direction
	_pending_throw_world_root = world_root
	_pending_throw_from_crowd = from_crowd
	
	# For crowd throws, execute immediately (no animation)
	if from_crowd:
		_execute_throw()
		return
	
	# Trigger throw animation on the holder and wait for throw_frame
	if _pickupable:
		var holder = _pickupable.get_holder()
		if holder:
			# Look for AnimationController on the holder
			var anim_controller: AnimationController = holder.get_node_or_null("AnimationController")
			if anim_controller:
				_throw_animation_controller = anim_controller
				# Speed up throw animation to hit throw_frame at ~0.25s
				# Standard throw animation is probably ~1s, so 4x speed = 0.25s
				anim_controller.set_attack_animation_speed(4.0)
				# Connect to throw_frame signal if not already connected
				if not anim_controller.throw_frame.is_connected(_on_throw_frame):
					anim_controller.throw_frame.connect(_on_throw_frame)
				# Start the throw animation
				anim_controller.request_action(&"throw")
				return
	
	# Fallback: no animation controller, execute immediately
	_execute_throw()

## Called when throw_frame signal is emitted during throw animation
func _on_throw_frame() -> void:
	# Reset animation speed after throw frame
	if _throw_animation_controller:
		_throw_animation_controller.reset_attack_animation_speed()
		_throw_animation_controller = null
	
	# Execute the actual throw
	_execute_throw()

## Executes the actual throwing physics and effects
func _execute_throw() -> void:
	var item: Node = get_parent()
	if not item is RigidBody3D:
		return
	var rb: RigidBody3D = item as RigidBody3D
	var old_global_pos: Vector3 = rb.global_position
	
	# Reparent and release item
	item.reparent(_pending_throw_world_root)
	rb.global_position = old_global_pos
	rb.freeze = false
	if _pickupable:
		_pickupable.clear_holder()

	# Reset landing state for new throw
	_has_landed = false
	_is_from_crowd = _pending_throw_from_crowd

	# Store original collision layer and disable PLAYER_INTERACTION layer during flight
	_original_collision_mask = rb.collision_mask
	rb.collision_mask = rb.collision_mask & ~CollisionLayers.get_mask(CollisionLayers.Layer.PLAYER_INTERACTION)

	# Throw direction: blend horizontal direction with upward bias
	var up := Vector3.UP
	var flat := Vector3(_pending_throw_direction.x, 0.0, _pending_throw_direction.z)
	if flat.length_squared() > 0.01:
		flat = flat.normalized()
	var throw_dir := (flat * (1.0 - throw_up_bias) + up * throw_up_bias).normalized()
	rb.apply_central_impulse(throw_dir * throw_force)

	# Execute OnThrowEffect components
	EffectUtils.execute_effects(item, OnThrowEffect, [throw_dir, throw_force, _pending_throw_from_crowd])

	# Emit thrown signal
	thrown.emit(throw_dir, throw_force, _pending_throw_from_crowd)

	# Emit global event for upgrade system
	EventBus.weapon_thrown.emit(item, throw_dir, _pending_throw_from_crowd)


## Mark this item as being thrown by the crowd (won't take durability damage on landing)
## Call this before applying custom throw physics
func mark_as_crowd_throw() -> void:
	_has_landed = false
	_is_from_crowd = true


## Handle collision when thrown item hits something
func _on_body_entered(body: Node) -> void:
	if _has_landed:
		return  # Only trigger on first collision

	_has_landed = true

	# Restore original collision layer (re-enable PLAYER_INTERACTION)
	if _item and _original_collision_mask != 0:
		_item.collision_mask = _original_collision_mask

	print("ThrowableBehaviour: %s landed (hit %s), from_crowd=%s" % [_item.name, body.name, _is_from_crowd])

	# Check if we hit an enemy and apply damage
	if body is Enemy:
		var enemy = body as Enemy
		enemy.take_damage(throw_collision_damage, _item)
		print("  -> Hit enemy for %d damage" % throw_collision_damage)

	# Apply durability cost if not from crowd
	if not _is_from_crowd:
		# Find any WeaponBehaviour (including subclasses like MeleeWeaponBehaviour)
		if _weapon_behaviour:
			print("  -> Applying %d durability damage to weapon" % throw_durability_cost)
			_weapon_behaviour.damage_weapon(throw_durability_cost)
			for child in _item.get_children():
				if child is OnEnemyHitEffect:
					child.execute(body, throw_collision_damage)
		else:
			print("  -> No WeaponBehaviour found, skipping durability damage")

	# Execute OnThrowLandedEffect components
	EffectUtils.execute_effects(_item, OnThrowLandedEffect, [body])

	# Emit landed signal
	throw_landed.emit(null)
