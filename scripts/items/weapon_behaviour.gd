extends Node
class_name WeaponBehaviour


## Base weapon behavior for all weapons
## Handles durability, events, and shared weapon logic

## Emitted when weapon is picked up
signal weapon_picked_up(picker: Node3D)
## Emitted when weapon is thrown
signal weapon_thrown(direction: Vector3, force: float)
## Emitted when weapon is destroyed
signal weapon_destroyed()
## Emitted when weapon attacks
signal weapon_attacked()
## Emitted when durability changes
signal durability_changed(current: int, max: int)

## Maximum durability
@export var max_durability: int = 100
## Damage dealt by this weapon
@export var damage: float = 10.0
## Cooldown between attacks in seconds
@export var attack_cooldown: float = 0.5
## Whether this weapon can be thrown
@export var can_be_thrown: bool = true
## Whether weapon breaks when durability reaches zero
@export var breaks_on_zero_durability: bool = true
## Sound to play when weapon is destroyed
@export var destroy_sound: AudioStream = preload("res://resources/sounds/breaking-1.mp3")

## Current durability
var current_durability: int
## Whether weapon is currently held by player
var is_held: bool = false
## Last attack time
var last_attack_time: float = 0.0

## Reference to parent item
var item: Node3D


func _ready() -> void:
	item = get_parent() as Node3D
	if not item:
		push_error("WeaponBehaviour must be child of Node3D item")
		return

	current_durability = max_durability

	# Connect to existing behaviors
	_connect_to_pickup_behaviour()
	_connect_to_throwable_behaviour()


## Connect to PickupableBehaviour signals
func _connect_to_pickup_behaviour() -> void:
	var pickupable = item.get_node_or_null("PickupableBehaviour")
	if pickupable and pickupable.has_signal("picked_up"):
		pickupable.picked_up.connect(_handle_pickup)
		pickupable.dropped.connect(_handle_drop)


## Connect to ThrowableBehaviour signals
func _connect_to_throwable_behaviour() -> void:
	var throwable = item.get_node_or_null("ThrowableBehaviour")
	if throwable and throwable.has_signal("thrown"):
		throwable.thrown.connect(_handle_throw)
	if throwable and throwable.has_signal("throw_landed"):
		throwable.throw_landed.connect(_handle_throw_landed)


## Perform attack (calls _attack if not on cooldown)
func attack() -> bool:
	if is_on_cooldown():
		return false

	_attack()
	last_attack_time = Time.get_ticks_msec() / 1000.0

	# Execute OnAttackEffect components
	EffectUtils.execute_effects(item, OnAttackEffect)

	weapon_attacked.emit()

	# Damage weapon on attack
	damage_weapon(1)

	return true


## Check if weapon is on cooldown
func is_on_cooldown() -> bool:
	var current_time = Time.get_ticks_msec() / 1000.0
	return (current_time - last_attack_time) < attack_cooldown


## Damage the weapon
func damage_weapon(amount: float) -> void:
	current_durability = max(0, current_durability - amount)
	durability_changed.emit(current_durability, max_durability)

	if current_durability <= 0 and breaks_on_zero_durability:
		destroy()


## Destroy the weapon
func destroy() -> void:
	print("WeaponBehaviour: %s destroyed (durability: %d/%d)" % [item.name, current_durability, max_durability])

	# Execute all OnDestroyEffect components
	EffectUtils.execute_effects(item, OnDestroyEffect)

	# Emit global event for upgrade system
	EventBus.weapon_broken.emit(item)

	# TODO: Spawn break particles (wood splinters, metal shards, etc.)

	# Play destruction sound
	if destroy_sound:
		Audio.play_sound(destroy_sound, Audio.Channels.SFX)

	_on_destroyed()
	weapon_destroyed.emit()

	if item:
		item.queue_free()


## Handle pickup event from PickupableBehaviour
func _handle_pickup(picker: Node3D) -> void:
	is_held = true
	_on_pickup(picker)
	weapon_picked_up.emit(picker)
	# Execute OnPickupEffect components
	EffectUtils.execute_effects(item, OnPickupEffect, [picker])


## Handle drop event from PickupableBehaviour
func _handle_drop() -> void:
	is_held = false


## Handle throw event from ThrowableBehaviour
func _handle_throw(direction: Vector3, force: float, _from_crowd: bool) -> void:
	_on_throw(direction, force)
	weapon_thrown.emit(direction, force)


## Handle throw landed event from ThrowableBehaviour
func _handle_throw_landed(collision) -> void:
	_on_throw_landed(collision)


## VIRTUAL: Override to implement attack logic
func _attack() -> void:
	push_warning("WeaponBehaviour._attack() not implemented for ", item.name)


## VIRTUAL: Override for custom pickup behavior
func _on_pickup(_picker: Node3D) -> void:
	pass


## VIRTUAL: Override for custom throw behavior
func _on_throw(_direction: Vector3, _force: float) -> void:
	pass


## VIRTUAL: Override for custom throw landed behavior
func _on_throw_landed(_collision) -> void:
	pass


## VIRTUAL: Override for custom destroy behavior
func _on_destroyed() -> void:
	pass
