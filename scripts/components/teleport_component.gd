extends Node
class_name TeleportComponent

## Component that grants teleportation ability to the holder
## Attaches to player when item is picked up, detaches on drop/destroy

@export var teleport_distance: float = 10.0  ## Maximum teleport distance
@export var cooldown: float = 1.0  ## Cooldown between teleports in seconds

var _player: Node3D = null
var _item: Node3D = null
var _pickupable: PickupableBehaviour = null
var _cooldown_timer: Timer = null


func _ready() -> void:
	# Create cooldown timer
	_cooldown_timer = Timer.new()
	_cooldown_timer.wait_time = cooldown
	_cooldown_timer.one_shot = true
	add_child(_cooldown_timer)

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

	# Connect to pickup/drop signals
	_pickupable.picked_up.connect(_on_picked_up)
	_pickupable.dropped.connect(_on_dropped)


func _unhandled_input(event: InputEvent) -> void:
	# Only process input when attached to player
	if not _player:
		return

	if event.is_action_pressed("attack_melee"):
		_try_teleport()

## Attempt to teleport player to cursor position
func _try_teleport() -> void:
	if not _player:
		return

	# Check cooldown
	if not _cooldown_timer.is_stopped():
		return

	# Get cursor world position
	var cursor_pos = _get_cursor_world_position()
	if cursor_pos == null:
		print("TeleportComponent: failed to get cursor position")
		return

	# Check distance
	var distance = _player.global_position.distance_to(cursor_pos)
	if distance > teleport_distance:
		print("TeleportComponent: too far (%.1fm, max %.1fm)" % [distance, teleport_distance])
		return

	# Teleport!
	print("TeleportComponent: teleporting to %s" % cursor_pos)
	_player.global_position = cursor_pos
	_cooldown_timer.start()


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
	print("TeleportComponent: picked up by %s" % picker.name)
	_player = picker

	# Reparent to player to process input
	reparent(picker)


## Called when item is dropped
func _on_dropped() -> void:
	print("TeleportComponent: dropped")
	_player = null

	# Reparent back to item
	if _item:
		reparent(_item)
