extends Node
class_name TeleportComponent

## Component that grants teleportation ability to the holder
## Attaches to player when item is picked up, detaches on drop/destroy

@export var teleport_distance: float = 10.0  ## Maximum teleport distance
@export var cooldown: float = 1.0  ## Cooldown between teleports in seconds
@export var aim_time_scale: float = 0.2  ## Time scale when aiming
@export var line_dash_length: float = 0.3  ## Length of each dash in the preview line
@export var line_gap_length: float = 0.2  ## Gap between dashes
@export var player_radius: float = 0.5  ## Player collision radius for wall detection

var _player: Node3D = null
var _item: Node3D = null
var _pickupable: PickupableBehaviour = null
var _weapon: WeaponBehaviour = null
var _cooldown_timer: Timer = null
var _is_aiming: bool = false
var _aim_line: Node3D = null
var _player_preview: Node3D = null
var _target_position: Vector3 = Vector3.ZERO
var _line_material: StandardMaterial3D = null
var _time_scale_effect_id: String = ""


func _ready() -> void:
	# Create cooldown timer
	_cooldown_timer = Timer.new()
	_cooldown_timer.wait_time = cooldown
	_cooldown_timer.one_shot = true
	add_child(_cooldown_timer)

	# Create reusable line material
	_line_material = StandardMaterial3D.new()
	_line_material.albedo_color = Color.WHITE
	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Find parent item and its pickupable behaviour
	_item = get_parent() as Node3D
	if not _item:
		push_error("TeleportComponent: parent must be a Node3D item")
		return

	# Find PickupableBehaviour
	_pickupable = _item.get_node_or_null("PickupableBehaviour")
	if not _pickupable:
		push_warning("TeleportComponent: no PickupableBehaviour found on %s" % _item.name)
		return

	# Find WeaponBehaviour for durability
	_weapon = _item.get_node_or_null("WeaponBehaviour")
	if not _weapon:
		push_warning("TeleportComponent: no WeaponBehaviour found on %s (item won't have durability)" % _item.name)
	else:
		# Connect to destruction signal to clean up when weapon breaks
		_weapon.weapon_destroyed.connect(_on_weapon_destroyed)

	# Connect to pickup/drop signals
	_pickupable.picked_up.connect(_on_picked_up)
	_pickupable.dropped.connect(_on_dropped)


func _process(_delta: float) -> void:
	if _is_aiming:
		_update_aim_preview()


func _unhandled_input(event: InputEvent) -> void:
	# Only process input when attached to player
	if not _player:
		return

	if event.is_action_pressed("attack_melee"):
		_start_aiming()
	elif event.is_action_released("attack_melee"):
		if _is_aiming:
			_execute_teleport()


## Start aiming mode
func _start_aiming() -> void:
	# Check cooldown
	if not _cooldown_timer.is_stopped():
		return
	_is_aiming = true
	_time_scale_effect_id = TimeScaleManager.request_time_scale(aim_time_scale)


## Execute the teleport
func _execute_teleport() -> void:
	_is_aiming = false
	_cancel_time_scale_effect()

	# Clean up previews
	_clear_previews()

	# Check if we have a valid player and target
	if not _player or not is_instance_valid(_player):
		print("TeleportComponent: no valid player")
		return

	# Store start position for event
	var from_position = _player.global_position

	# Teleport to preview location!
	_player.global_position = _target_position
	_cooldown_timer.start()

	# Emit global event for upgrade system
	EventBus.player_teleported.emit(from_position, _target_position)

	# Damage the weapon on use
	if _weapon:
		_weapon.damage_weapon(1)


## Update aim preview (line and player ghost)
func _update_aim_preview() -> void:
	if not _player or not is_instance_valid(_player):
		_clear_previews()
		_is_aiming = false
		_cancel_time_scale_effect()
		return

	var cursor_pos = _get_cursor_world_position()
	if cursor_pos == Vector3.ZERO:
		_clear_previews()
		return

	var distance = _player.global_position.distance_to(cursor_pos)

	# Clamp cursor position to max distance
	if distance > teleport_distance:
		var direction = (cursor_pos - _player.global_position).normalized()
		cursor_pos = _player.global_position + direction * teleport_distance

	# Check for walls and clamp position before collision
	cursor_pos = _clamp_to_wall_collision(cursor_pos)

	# Store the target position for teleport execution
	_target_position = cursor_pos

	# Update dashed line
	_update_dashed_line(_player.global_position, cursor_pos)

	# Update player preview
	_update_player_preview(cursor_pos)


## Create or update the dashed line from player to target
func _update_dashed_line(from: Vector3, to: Vector3) -> void:
	# Clear existing line
	if _aim_line:
		_aim_line.queue_free()
		_aim_line = null

	# Create container for line segments
	_aim_line = Node3D.new()
	_aim_line.name = "TeleportLine"
	get_tree().root.add_child(_aim_line)

	var direction = (to - from).normalized()
	var total_distance = from.distance_to(to)
	var current_distance = 0.0

	# Create dashed line segments using cylinders for thickness
	while current_distance < total_distance:
		var dash_end_dist = min(current_distance + line_dash_length, total_distance)
		var actual_dash_length = dash_end_dist - current_distance

		if actual_dash_length <= 0:
			break

		# Create cylinder for this dash
		var mesh_instance = MeshInstance3D.new()
		var cylinder = CylinderMesh.new()
		cylinder.top_radius = 0.05  # Thickness
		cylinder.bottom_radius = 0.05
		cylinder.height = actual_dash_length
		mesh_instance.mesh = cylinder
		mesh_instance.material_override = _line_material

		# Add to tree first
		_aim_line.add_child(mesh_instance)

		# Position and orient the cylinder
		var dash_center = from + direction * (current_distance + actual_dash_length * 0.5)
		mesh_instance.global_position = dash_center

		# Rotate cylinder to align with direction
		var up = Vector3.UP
		if abs(direction.dot(up)) > 0.99:
			up = Vector3.RIGHT
		mesh_instance.look_at(dash_center + direction, up)
		mesh_instance.rotate_object_local(Vector3.RIGHT, PI / 2)

		# Move to next dash
		current_distance += line_dash_length + line_gap_length


## Create or update the player preview at target location
func _update_player_preview(position: Vector3) -> void:
	# Clear existing preview
	if _player_preview:
		_player_preview.queue_free()
		_player_preview = null

	# Find player mesh to clone
	var player_mesh = _find_player_mesh()
	if not player_mesh:
		return

	# Create preview container
	_player_preview = Node3D.new()
	_player_preview.name = "TeleportPreview"
	get_tree().root.add_child(_player_preview)
	_player_preview.global_position = position

	# Clone player mesh
	var mesh_copy = player_mesh.duplicate()
	_player_preview.add_child(mesh_copy)

	# Make it semi-transparent white
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.albedo_color.a = 0.3
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_copy.material_override = material


## Find the player's visual mesh
func _find_player_mesh() -> MeshInstance3D:
	if not _player:
		return null

	# Look for MeshInstance3D in player's children
	for child in _player.get_children():
		if child is MeshInstance3D:
			return child
		# Check nested children
		for nested in child.get_children():
			if nested is MeshInstance3D:
				return nested

	return null


## Clear all preview visuals
func _clear_previews() -> void:
	if _aim_line:
		_aim_line.queue_free()
		_aim_line = null

	if _player_preview:
		_player_preview.queue_free()
		_player_preview = null


## Check for wall collisions and clamp target position
func _clamp_to_wall_collision(target_pos: Vector3) -> Vector3:
	if not _player:
		return target_pos

	var from = _player.global_position + Vector3.UP * 0.5
	var to = target_pos

	# Create raycast query
	var space_state = _player.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Environment layer
	query.exclude = [_player, _item]  # Don't hit the player or item

	# Perform raycast
	var result = space_state.intersect_ray(query)

	# No collision, use original target
	if result.is_empty():
		return target_pos

	# Hit a wall - clamp position to just before the wall
	var hit_point = result.position
	var direction = (to - from).normalized()

	# Move back by player radius to avoid clipping into wall
	var safe_position = hit_point - direction * player_radius

	print("TeleportComponent: wall detected at %s, clamping to %s" % [hit_point, safe_position])
	return safe_position




## Get world position of cursor on the ground plane
func _get_cursor_world_position() -> Vector3:
	var viewport = get_viewport()
	if not viewport:
		return Vector3.ZERO

	var camera = viewport.get_camera_3d()
	if not camera:
		return Vector3.ZERO

	var mouse_pos = viewport.get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)

	# Intersect with ground plane (y = player's y position)
	var player_y = _player.global_position.y
	if abs(ray_direction.y) < 0.001:
		return Vector3.ZERO  # Ray is parallel to ground

	var t = (player_y - ray_origin.y) / ray_direction.y
	if t < 0:
		return Vector3.ZERO  # Behind camera

	return ray_origin + ray_direction * t


## Called when item is picked up
func _on_picked_up(picker: Node3D) -> void:
	_player = picker
	# Reparent to player to process input
	reparent(picker)


## Called when item is dropped
func _on_dropped() -> void:
	# Clean up if we were aiming
	if _is_aiming:
		_is_aiming = false
		_cancel_time_scale_effect()
		_clear_previews()

	_player = null

	# Reparent back to item
	if _item:
		reparent(_item)


## Called when weapon is destroyed
func _on_weapon_destroyed() -> void:
	# Clean up if we were aiming
	if _is_aiming:
		_is_aiming = false
		_cancel_time_scale_effect()
		_clear_previews()

	_player = null

	# Remove ourselves since the parent item is being destroyed
	queue_free()


## Cancel the active time scale effect if one exists
func _cancel_time_scale_effect() -> void:
	if _time_scale_effect_id != "":
		TimeScaleManager.cancel_time_scale(_time_scale_effect_id)
		_time_scale_effect_id = ""
