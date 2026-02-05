extends CharacterBody3D

const SurfaceDetectorClass = preload("res://scripts/surfaces/surface_detector.gd")
const PlayerInventoryClass = preload("res://scripts/player/player_inventory.gd")
const SelectionWheelClass = preload("res://scripts/ui/selection_wheel.gd")

## Move speed in m/s
@export var move_speed: float = 6.0
## Downward acceleration when in the air
@export var gravity: float = 9.8
## Max distance to pick up an item
@export var pickup_range: float = 2.0
## How quickly the character rotates to face movement direction (higher is faster)
@export var facing_turn_speed: float = 30.0
## Player health
@export var max_health: float = 100.0
## Sound played when player takes damage
@export var hit_sound: AudioStream
## Material to use when flashing from damage
@export var hit_flash_material: Material
## Duration of the damage flash in seconds
@export var hit_flash_duration: float = 0.15

signal health_changed(current: float, maximum: float)
signal died()

var current_health: float = max_health
## Facing direction on XZ plane (x, z). Normalized when used for rotation.
var _facing_direction: Vector2 = Vector2(0.0, -1.0) # Start facing -Z (forward)

# Selection wheel variables
var _selection_wheel: SelectionWheelClass = null
var _original_time_scale: float = 1.0

# Get inventory from scene instead of creating it
@onready var _inventory: PlayerInventoryClass = $PlayerInventory
@onready var _mesh: MeshInstance3D = $MeshInstance3D

# Movement components
var _dash_component: DashComponent = null
var _movement_components: Array[MovementComponent] = []
var _surface_detector: SurfaceDetector = null

# Damage flash
var _flash_timer: Timer = null

func _ready() -> void:
	add_to_group("player")
	current_health = max_health
	_cache_movement_components()
	_setup_inventory_system()
	_setup_damage_flash()


func _cache_movement_components() -> void:
	for child in get_children():
		if child is DashComponent:
			_dash_component = child

		if child is MovementComponent:
			_movement_components.append(child)

		if child is SurfaceDetectorClass:
			_surface_detector = child

func _physics_process(delta: float) -> void:
	# Check if any movement component is currently active
	var active_component: MovementComponent = null
	for component in _movement_components:
		if component.is_active():
			active_component = component
			break

	# If a movement ability is active, let it control velocity
	if active_component:
		var ability_velocity := active_component.apply_velocity(delta)
		velocity.x = ability_velocity.x
		velocity.z = ability_velocity.z
		velocity.y = ability_velocity.y
		move_and_slide()
		return

	# Handle movement ability inputs
	if Input.is_action_just_pressed("dash") and _dash_component and _dash_component.can_activate():
		_dash_component.activate(velocity)
		return # Skip normal movement this frame

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
		# Apply surface effect to movement speed
		var effective_speed = move_speed
		if _surface_detector:
			effective_speed *= _surface_detector.get_speed_multiplier()
		effective_speed *= _get_speed_multiplier_from_weapon()
		
		velocity.x = direction.x * effective_speed
		velocity.z = direction.z * effective_speed
		# Gradually rotate to face movement direction (2D XZ only)
		var target_facing := Vector2(direction.x, direction.z).normalized()
		_facing_direction = _facing_direction.lerp(target_facing, facing_turn_speed * delta)
		if _facing_direction.length_squared() > 0.01:
			_facing_direction = _facing_direction.normalized()
			rotation.y = - atan2(_facing_direction.x, -_facing_direction.y)
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_pick_up()
	if event.is_action_pressed("throw"):
		_try_throw()
	if event.is_action_pressed("primary_interact"):
		_try_primary_interact()

	# Inventory selection wheel
	if event.is_action_pressed("inventory_select"):
		_show_selection_wheel()
	if event.is_action_released("inventory_select"):
		_hide_selection_wheel()


func _try_pick_up() -> void:
	if not _inventory or _inventory.is_full():
		print("Player: Inventory full, cannot pick up item")
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
		if behaviour and behaviour.try_pick_up(self ):
			_inventory.add_item(closest)
			behaviour.dropped.connect(_on_item_dropped_from_world)


func _get_pickupable_behaviour(item_root: Node) -> PickupableBehaviour:
	for c in item_root.get_children():
		if c is PickupableBehaviour:
			return c as PickupableBehaviour
	return null


func _try_throw() -> void:
	if not _inventory:
		return
	
	var active_item = _inventory.get_active_item()
	if not active_item or not is_instance_valid(active_item):
		return
	
	var throwable: ThrowableBehaviour = _get_throwable_behaviour(active_item)
	if not throwable:
		return
	
	var pickupable: PickupableBehaviour = _get_pickupable_behaviour(active_item)
	if pickupable and pickupable.dropped.is_connected(_on_item_dropped_from_world):
		pickupable.dropped.disconnect(_on_item_dropped_from_world)

	# Remove from inventory before throwing
	_inventory.remove_item(_inventory.active_item_index)
	
	# Throw towards cursor position instead of facing direction
	var throw_direction = _get_cursor_direction()
	throwable.throw(throw_direction, get_tree().current_scene)


func _get_throwable_behaviour(item_root: Node) -> ThrowableBehaviour:
	for c in item_root.get_children():
		if c is ThrowableBehaviour:
			return c as ThrowableBehaviour
	return null


## Get throw direction towards mouse cursor on XZ plane
func _get_cursor_direction() -> Vector3:
	var viewport = get_viewport()
	var camera = viewport.get_camera_3d()
	if not camera:
		# Fallback to facing direction if no camera
		return get_facing_direction()

	var mouse_pos = viewport.get_mouse_position()

	# Cast ray from camera through mouse position
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)

	# Project onto XZ plane at player's Y level
	var y_level = global_position.y
	if abs(ray_direction.y) > 0.001:
		var t = (y_level - ray_origin.y) / ray_direction.y
		var hit_point = ray_origin + ray_direction * t

		# Calculate direction from player to hit point
		var direction = (hit_point - global_position).normalized()
		return direction

	# Fallback: use ray direction flattened to XZ
	return Vector3(ray_direction.x, 0, ray_direction.z).normalized()


func _try_primary_interact() -> void:
	if not _inventory:
		return

	var weapon = _inventory.get_active_weapon()
	if weapon:
		weapon.attack()


func _get_speed_multiplier_from_weapon() -> float:
	if not _inventory:
		return 1.0

	var weapon = _inventory.get_active_weapon()
	if weapon and weapon is MeleeWeaponBehaviour:
		var melee_weapon = weapon as MeleeWeaponBehaviour
		if melee_weapon.is_attacking:
			return melee_weapon.speed_multiplier_when_attacking

	return 1.0

func _setup_damage_flash() -> void:
	_flash_timer = Timer.new()
	_flash_timer.one_shot = true
	_flash_timer.timeout.connect(_on_flash_timer_timeout)
	add_child(_flash_timer)


func _trigger_damage_flash() -> void:
	if _mesh and hit_flash_material:
		_mesh.material_override = hit_flash_material
		_flash_timer.start(hit_flash_duration)


func _on_flash_timer_timeout() -> void:
	if _mesh:
		_mesh.material_override = null


func _setup_inventory_system() -> void:
	# Create selection wheel UI only
	var selection_wheel_scene = preload("res://scenes/ui/SelectionWheel.tscn")
	_selection_wheel = selection_wheel_scene.instantiate() as SelectionWheelClass
	_selection_wheel.set_inventory(_inventory)
	_selection_wheel.item_selected.connect(_on_item_selected)
	
	# Add to scene tree (attach to root to be above other UI)
	get_tree().root.add_child.call_deferred(_selection_wheel)


func _show_selection_wheel() -> void:
	if _selection_wheel:
		_original_time_scale = Engine.time_scale
		Engine.time_scale = 0.3 # Slow down to 30%
		_selection_wheel.show_wheel()


func _hide_selection_wheel() -> void:
	if _selection_wheel:
		Engine.time_scale = _original_time_scale
		_selection_wheel.hide_wheel()


func _on_item_selected(slot: int) -> void:
	if _inventory:
		_inventory.set_active_item(slot)


func _on_item_dropped_from_world() -> void:
	# This is called when an item is dropped back into the world
	# The inventory system handles removing it from inventory
	pass


## Takes damage from an enemy or other source
func take_damage(amount: float, _source: Node3D = null) -> void:
	if current_health <= 0:
		return # Already dead

	current_health -= amount
	health_changed.emit(current_health, max_health)

	if hit_sound:
		Audio.play_sound(hit_sound, Audio.Channels.SFX)

	_trigger_damage_flash()

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
