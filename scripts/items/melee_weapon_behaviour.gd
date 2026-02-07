extends "res://scripts/items/weapon_behaviour.gd"
class_name MeleeWeaponBehaviour

## Melee weapon behavior for close-range attacks
## Uses area detection to hit nearby entities

const Layers = preload("res://scripts/core/collision_layers.gd")

## Whether to show the hitbox sphere for debugging
const DEBUG_SHOW_HITBOX: bool = true

## Distance from player where the stab starts
@export var stab_start_distance: float = 0.5
## Distance from player where the stab ends
@export var stab_end_distance: float = 1.5
## Radius of the stab hitbox
@export var stab_radius: float = 0.3
## Time in seconds before the stab hitbox becomes active
@export var stab_start_time: float = 0.1
## Time in seconds when the stab completes (hitbox reaches end distance)
@export var stab_end_time: float = 0.3
## Knockback force applied to hit entities
@export var knockback_force: float = 5.0
## How much to slow player movement when attacking (1 = normal speed, 0 = no movement)
@export var speed_multiplier_when_attacking: float = 0.5
## Collision mask for what can be hit (default: enemies and items)
@export var hit_collision_mask: int = 12 # Layer 3 (ENEMY) + Layer 4 (ITEM)


## Tracks which entities have been hit during current stab (to avoid double hits)
var _hit_entities: Array[Node3D] = []
## Current stab attack direction (stored for duration of attack)
var _stab_direction: Vector3 = Vector3.ZERO
## Current stab attack origin (stored for duration of attack)
var _stab_origin: Vector3 = Vector3.ZERO
## The hitbox sphere used for both collision detection and visualization
var _hitbox_sphere: Area3D = null
## The collision shape inside the hitbox sphere
var _hitbox_shape: SphereShape3D = null
## Whether an attack is currently in progress
var is_attacking: bool = false
## Whether to use animation-driven hit frames instead of tween timing
var use_animation_hit_frames: bool = false
## Hit frame has been triggered by animation controller
var hit_frame_ready: bool = false
## Reference to connected animation controller (for cleanup on drop)
var _anim_controller: AnimationController = null


## Helper method to get holder through PickupableBehaviour
func _get_holder() -> Node3D:
	var pickupable_behaviour = item.get_children().filter(func(child): return child is PickupableBehaviour)
	if pickupable_behaviour.is_empty():
		return null
	
	return (pickupable_behaviour[0] as PickupableBehaviour).get_holder()


func _ready() -> void:
	super._ready()


func _on_pickup(picker: Node3D) -> void:
	_try_connect_to_animation_controller(picker)


func _handle_drop() -> void:
	_disconnect_from_animation_controller()
	super._handle_drop()


func _try_connect_to_animation_controller(holder: Node3D) -> void:
	_disconnect_from_animation_controller()
	if not holder:
		return

	var anim_controller = holder.get_node_or_null("AnimationController")
	if anim_controller:
		# Connect to attack window events for proper timing
		if anim_controller.has_signal("attack_window"):
			if not anim_controller.attack_window.is_connected(_on_attack_window):
				anim_controller.attack_window.connect(_on_attack_window)
		
		# Also connect to hit frame for backwards compatibility
		if anim_controller.has_signal("hit_frame"):
			if not anim_controller.hit_frame.is_connected(_on_animation_hit_frame):
				anim_controller.hit_frame.connect(_on_animation_hit_frame)
		
		_anim_controller = anim_controller
		use_animation_hit_frames = true


func _disconnect_from_animation_controller() -> void:
	if _anim_controller and is_instance_valid(_anim_controller):
		if _anim_controller.has_signal("attack_window") and _anim_controller.attack_window.is_connected(_on_attack_window):
			_anim_controller.attack_window.disconnect(_on_attack_window)
		if _anim_controller.has_signal("hit_frame") and _anim_controller.hit_frame.is_connected(_on_animation_hit_frame):
			_anim_controller.hit_frame.disconnect(_on_animation_hit_frame)
	_anim_controller = null
	use_animation_hit_frames = false


func _cleanup_hitbox_sphere() -> void:
	if _hitbox_sphere and is_instance_valid(_hitbox_sphere):
		_hitbox_sphere.queue_free()
		_hitbox_sphere = null


## Override attack to perform animated stab
func _attack() -> void:
	if not item or not is_held:
		return

	print("MeleeWeaponBehaviour: attacking with ", item.name)

	is_attacking = true
	hit_frame_ready = false

	# Get attack origin (weapon position or holder position)
	_stab_origin = item.global_position

	# Get attack direction towards mouse cursor
	_stab_direction = _get_mouse_direction(_stab_origin)

	# Reset hit tracking for new attack
	_hit_entities.clear()

	if use_animation_hit_frames:
		# Use animation-driven timing
		_start_animation_driven_attack()
	else:
		# Use legacy tween-based timing
		_start_tween_driven_attack()

func _start_animation_driven_attack() -> void:
	"""Start attack that waits for animation attack window events"""
	# Don't create hitbox yet - wait for attack window to open
	print("MeleeWeaponBehaviour: Waiting for animation attack window to open")

func _start_tween_driven_attack() -> void:
	"""Legacy tween-based attack timing"""
	# Create tween for animated stab
	var tween = create_tween()

	# Wait for start time before activating hitbox
	if stab_start_time > 0:
		tween.tween_interval(stab_start_time)

	# Create hitbox sphere when the stab actually starts
	tween.tween_callback(_create_hitbox_sphere)

	# Animate from start to end distance
	var stab_duration = stab_end_time - stab_start_time
	tween.tween_method(_stab_tick, 0.0, 1.0, stab_duration)

	# Clean up after stab completes
	tween.tween_callback(_stab_finished)


## Called each frame during stab animation
func _stab_tick(progress: float) -> void:
	if not _hitbox_sphere or not is_instance_valid(_hitbox_sphere):
		return

	# Calculate current distance along stab
	var current_distance = lerpf(stab_start_distance, stab_end_distance, progress)
	var stab_position = _stab_origin + _stab_direction * current_distance

	# Update hitbox position
	_hitbox_sphere.global_position = stab_position

	# Only check for overlapping bodies if monitoring is enabled
	if not _hitbox_sphere.monitoring:
		return
		
	# Check for overlapping bodies using the Area3D
	var overlapping_bodies = _hitbox_sphere.get_overlapping_bodies()

	for hit_body in overlapping_bodies:
		# Don't hit self or holder
		if hit_body == item:
			continue

		# Don't hit same entity twice in one stab
		if hit_body in _hit_entities:
			continue

		_hit_entities.append(hit_body)
		_apply_hit(hit_body, _stab_direction)


## Called when stab animation completes
func _stab_finished() -> void:
	print("MeleeWeaponBehaviour: hit %d targets" % _hit_entities.size())
	is_attacking = false
	hit_frame_ready = false
	_cleanup_hitbox_sphere()

## Animation controller hit frame callback
func _on_animation_hit_frame() -> void:
	"""Called when animation controller triggers hit frame"""
	if not is_attacking or hit_frame_ready:
		return  # Not attacking or already triggered
		
	hit_frame_ready = true
	print("MeleeWeaponBehaviour: Animation hit frame triggered!")
	
	# Activate hitbox and perform attack
	if _hitbox_sphere:
		_hitbox_sphere.monitoring = true
		
		# Animate stab from start to end position over short duration
		var stab_duration = stab_end_time - stab_start_time
		var tween = create_tween()
		tween.tween_method(_stab_tick, 0.0, 1.0, stab_duration)
		tween.tween_callback(_stab_finished)


## Animation controller attack window callback
func _on_attack_window(open: bool) -> void:
	"""Called when animation controller triggers attack window open/close"""
	if not is_attacking:
		return
		
	if open:
		print("MeleeWeaponBehaviour: Attack window opened - starting hitbox")
		# Create and activate hitbox when attack window opens
		if not _hitbox_sphere:
			_create_hitbox_sphere()
		_hitbox_sphere.monitoring = true
		
		# Start the stab animation
		var stab_duration = stab_end_time - stab_start_time
		var tween = create_tween()
		tween.tween_method(_stab_tick, 0.0, 1.0, stab_duration)
	else:
		print("MeleeWeaponBehaviour: Attack window closed - ending attack")
		# End the attack when window closes
		_stab_finished()


## Apply damage and knockback to hit entity
func _apply_hit(target: Node3D, direction: Vector3) -> void:
	print("MeleeWeaponBehaviour: hit ", target.name, " for ", damage, " damage")

	var target_killed = false

	# Apply damage if target is an enemy
	if target is Enemy:
		var enemy = target as Enemy
		var health_before = enemy.current_health
		enemy.take_damage(damage, item)
		var health_after = enemy.current_health

		# Check if enemy was killed
		if health_before > 0 and health_after <= 0:
			target_killed = true

		# Execute OnEnemyHitEffect components
		EffectUtils.execute_effects(item, OnEnemyHitEffect, [target, damage])

		# Execute OnEnemyKilledEffect components if enemy died
		if target_killed:
			EffectUtils.execute_effects(item, OnEnemyKilledEffect, [target])

	# Apply knockback if target is RigidBody
	if target is RigidBody3D:
		var knockback_vector = direction.normalized() * knockback_force
		target.apply_central_impulse(knockback_vector)


## Get attack direction towards mouse cursor
func _get_mouse_direction(from_position: Vector3) -> Vector3:
	var viewport = item.get_viewport()
	var camera = viewport.get_camera_3d()
	if not camera:
		# Fallback to forward direction if no camera
		return -item.global_transform.basis.z

	var mouse_pos = viewport.get_mouse_position()

	# Cast ray from camera through mouse position
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)

	# Project onto XZ plane (ground level)
	var y_level = from_position.y
	if abs(ray_direction.y) > 0.001:
		var t = (y_level - ray_origin.y) / ray_direction.y
		var hit_point = ray_origin + ray_direction * t

		# Calculate direction from attack origin to hit point
		var direction = (hit_point - from_position).normalized()
		return direction

	# Fallback: use ray direction flattened to XZ
	return Vector3(ray_direction.x, 0, ray_direction.z).normalized()


## Create hitbox sphere for collision detection and optional visualization
func _create_hitbox_sphere() -> void:
	# Create Area3D as the hitbox container
	_hitbox_sphere = Area3D.new()
	_hitbox_sphere.collision_mask = hit_collision_mask
	_hitbox_sphere.collision_layer = 0 # Don't collide with anything, just detect
	_hitbox_sphere.monitoring = true

	# Create collision shape
	var collision_shape = CollisionShape3D.new()
	_hitbox_shape = SphereShape3D.new()
	_hitbox_shape.radius = stab_radius
	collision_shape.shape = _hitbox_shape
	_hitbox_sphere.add_child(collision_shape)

	# Create visual mesh if debug is enabled
	if DEBUG_SHOW_HITBOX:
		var mesh_instance = MeshInstance3D.new()
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = stab_radius
		sphere_mesh.height = stab_radius * 2.0

		var material = StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.0, 0.0, 0.3)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

		sphere_mesh.material = material
		mesh_instance.mesh = sphere_mesh
		_hitbox_sphere.add_child(mesh_instance)

	# Add to scene
	item.get_tree().root.add_child(_hitbox_sphere)

	# Set initial position at stab start
	_hitbox_sphere.global_position = _stab_origin + _stab_direction * stab_start_distance
