extends CharacterBody3D

## Move speed in m/s
@export var move_speed: float = 6.0
## Downward acceleration when in the air
@export var gravity: float = 9.8
## Max distance to pick up an item
@export var pickup_range: float = 2.0
## How quickly the character rotates to face movement direction (1 = instant, lower = smoother)
@export var facing_turn_speed: float = 8.0
## Dash speed (horizontal only)
@export var dash_speed: float = 15.0
## How long the dash lasts (seconds)
@export var dash_duration: float = 0.16
## Cooldown before next dash (seconds)
@export var dash_cooldown: float = 1
## Player health
@export var max_health: float = 100.0

signal health_changed(current: float, maximum: float)
signal died()

var current_health: float = max_health
var _held_item: Node3D = null # Root of the held item (e.g. Brick RigidBody3D)
var _held_melee_weapon: MeleeWeaponBehaviour = null
var _held_ranged_weapon: RangedWeaponBehaviour = null
## Facing direction on XZ plane (x, z). Normalized when used for rotation.
var _facing_direction: Vector2 = Vector2(0.0, -1.0) # Start facing -Z (forward)
var _dash_timer: float = 0.0
var _dash_cooldown_remaining: float = 0.0
var _dash_direction: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("player")
	current_health = max_health

func _physics_process(delta: float) -> void:
	# Dash: start on input, or apply velocity while active
	if Input.is_action_just_pressed("dash") and _dash_timer <= 0.0 and _dash_cooldown_remaining <= 0.0:
		var horizontal := Vector3(velocity.x, 0.0, velocity.z)
		if horizontal.length_squared() > 0.01:
			_dash_direction = horizontal.normalized()
		else:
			_dash_direction = get_facing_direction()
		_dash_timer = dash_duration
		_dash_cooldown_remaining = dash_cooldown

	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity.x = _dash_direction.x * dash_speed
		velocity.z = _dash_direction.z * dash_speed
		velocity.y = 0.0
		move_and_slide()
		return

	if _dash_cooldown_remaining > 0.0:
		_dash_cooldown_remaining -= delta

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Get input (WASD via move_* actions in Project Settings -> Input Map)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	# Movement relative to camera: W = up on screen, S = down, A/D = left/right
	var direction := Vector3.ZERO
	var cam := get_viewport().get_camera_3d()
	if cam:
		var cam_basis := cam.global_transform.basis
		# Screen "up" = from camera toward look-at, flattened to XZ
		var forward_screen := Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z)
		forward_screen = forward_screen.normalized()
		# Screen "right" = camera right, flattened to XZ
		var right_screen := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z)
		right_screen = right_screen.normalized()
		direction = (-input_dir.y * forward_screen + input_dir.x * right_screen)
		if direction.length_squared() > 0.0:
			direction = direction.normalized()
	else:
		# Fallback: world-relative (e.g. no camera)
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		# Gradually rotate to face movement direction (2D XZ only)
		var target_facing := Vector2(direction.x, direction.z).normalized()
		_facing_direction = _facing_direction.lerp(target_facing, facing_turn_speed * delta)
		if _facing_direction.length_squared() > 0.01:
			_facing_direction = _facing_direction.normalized()
			rotation.y = -atan2(_facing_direction.x, -_facing_direction.y)
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_pick_up()
	if event.is_action_pressed("throw"):
		_try_throw()
	if event.is_action_pressed("attack_melee"):
		_try_melee_attack()
	if event.is_action_pressed("attack_ranged"):
		_try_ranged_attack()


func _try_pick_up() -> void:
	if _held_item != null:
		return
	var pickups := get_tree().get_nodes_in_group("pickupable")
	var closest: Node3D = null
	var closest_dist_sq := pickup_range * pickup_range
	for node in pickups:
		if not node is Node3D:
			continue
		var n: Node3D = node as Node3D
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		var d_sq := global_position.distance_squared_to(n.global_position)
		if d_sq >= closest_dist_sq:
			continue
		var behaviour := _get_pickupable_behaviour(n)
		if behaviour == null or behaviour.is_held():
			continue
		closest = n
		closest_dist_sq = d_sq
	if closest != null:
		var behaviour: PickupableBehaviour = _get_pickupable_behaviour(closest)
		if behaviour and behaviour.try_pick_up(self):
			_held_item = closest
			_cache_weapon_behaviours(closest)
			behaviour.dropped.connect(_on_item_dropped)


func _get_pickupable_behaviour(item_root: Node) -> PickupableBehaviour:
	for c in item_root.get_children():
		if c is PickupableBehaviour:
			return c as PickupableBehaviour
	return null


func _try_throw() -> void:
	if _held_item == null or not is_instance_valid(_held_item):
		_held_item = null
		_held_melee_weapon = null
		_held_ranged_weapon = null
		return
	var throwable: ThrowableBehaviour = _get_throwable_behaviour(_held_item)
	if not throwable:
		return
	var pickupable: PickupableBehaviour = _get_pickupable_behaviour(_held_item)
	if pickupable and pickupable.dropped.is_connected(_on_item_dropped):
		pickupable.dropped.disconnect(_on_item_dropped)
	throwable.throw(get_facing_direction(), get_tree().current_scene)
	_held_item = null
	_held_melee_weapon = null
	_held_ranged_weapon = null


func _get_throwable_behaviour(item_root: Node) -> ThrowableBehaviour:
	for c in item_root.get_children():
		if c is ThrowableBehaviour:
			return c as ThrowableBehaviour
	return null


func _try_melee_attack() -> void:
	if _held_melee_weapon:
		_held_melee_weapon.attack()


func _try_ranged_attack() -> void:
	if _held_ranged_weapon:
		_held_ranged_weapon.attack()


func _cache_weapon_behaviours(item_root: Node) -> void:
	_held_melee_weapon = null
	_held_ranged_weapon = null
	for c in item_root.get_children():
		if c is MeleeWeaponBehaviour:
			_held_melee_weapon = c as MeleeWeaponBehaviour
		elif c is RangedWeaponBehaviour:
			_held_ranged_weapon = c as RangedWeaponBehaviour


func _on_item_dropped() -> void:
	_held_item = null
	_held_melee_weapon = null
	_held_ranged_weapon = null


## Takes damage from an enemy or other source
func take_damage(amount: float, _source: Node3D = null) -> void:
	if current_health <= 0:
		return  # Already dead

	current_health -= amount
	health_changed.emit(current_health, max_health)

	print("Player took %s damage. Health: %s/%s" % [amount, current_health, max_health])

	if current_health <= 0:
		current_health = 0
		die()


func die() -> void:
	print("Player died!")
	died.emit()
	# TODO: Death animation, respawn, game over screen, etc.


## Returns the character's current facing direction on the XZ plane (normalized).
## Use this for throw direction, aim, etc.
func get_facing_direction() -> Vector3:
	if _facing_direction.length_squared() < 0.01:
		return -global_transform.basis.z
	return Vector3(_facing_direction.x, 0.0, _facing_direction.y).normalized()
