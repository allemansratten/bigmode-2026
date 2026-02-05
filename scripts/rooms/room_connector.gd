extends Area3D
class_name RoomConnector

## Bidirectional connector for entering/exiting rooms
## Detects player interaction and triggers room transition
## Locks during combat waves, unlocks when room is cleared

const Layers = preload("res://scripts/core/collision_layers.gd")

## Target room ID to transition to (from SceneManager.Room enum)
@export var target_room_id: SceneManager.Room = SceneManager.Room.EXAMPLE_ROOM

## Unique identifier for this connector (e.g. "north", "south", "door_1")
@export var connector_id: String = ""

## Direction the player should face when spawning at this connectoror (in degrees)
@export var spawn_facing_degrees: float = 0.0

## Whether to start locked (lock during waves)
@export var start_locked: bool = true

## Colors for locked/unlocked states
@export var locked_color: Color = Color(0.9, 0.2, 0.2, 0.6)  # Red
@export var unlocked_color: Color = Color(0.2, 0.9, 0.3, 0.6)  # Green

## Visual indicator for the connector (optional)
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

## Current lock state
var is_locked: bool = false

## Material for color changes
var _material: StandardMaterial3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Set up collision layer/mask for player detection
	collision_layer = 0  # Don't exist in any layer
	collision_mask = Layers.get_mask(Layers.Layer.PLAYER)

	# Get or create material for color changes
	_setup_material()

	# Set initial lock state
	if start_locked:
		lock()
	else:
		unlock()

	# Listen for room events to lock/unlock
	EventBus.room_cleared.connect(_on_room_cleared)
	SceneManager.room_transition_completed.connect(_on_room_transition_completed)


func _setup_material() -> void:
	if mesh_instance and mesh_instance.mesh:
		# Get existing material or create new one
		var existing_mat = mesh_instance.mesh.surface_get_material(0)
		if existing_mat is StandardMaterial3D:
			# Duplicate to avoid affecting other instances
			_material = existing_mat.duplicate()
			mesh_instance.material_override = _material
		else:
			# Create new material
			_material = StandardMaterial3D.new()
			_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mesh_instance.material_override = _material


func _on_body_entered(_body: Node3D) -> void:
	if is_locked:
		print("RoomConnector '%s': locked, cannot transition" % connector_id)
		return

	# Collision mask ensures only player can trigger this, no need to check
	print("RoomConnector '%s': player entered, transitioning to room %d" % [connector_id, target_room_id])
	SceneManager.transition_to_room(target_room_id)


## Lock the connector (prevent transitions, show red)
func lock() -> void:
	is_locked = true
	_update_visual()
	print("RoomConnector '%s': locked" % connector_id)


## Unlock the connector (allow transitions, show green)
func unlock() -> void:
	is_locked = false
	_update_visual()
	print("RoomConnector '%s': unlocked" % connector_id)


func _update_visual() -> void:
	if _material:
		_material.albedo_color = locked_color if is_locked else unlocked_color


func _on_room_cleared(_room: Node3D) -> void:
	# Unlock when room is cleared
	unlock()


func _on_room_transition_completed(_room: Node3D) -> void:
	# Re-lock when entering a new room (waves will start)
	if start_locked:
		lock()


## Get the spawn position for a player entering through this connector
func get_spawn_position() -> Vector3:
	return global_position


## Get the spawn rotation for a player entering through this connector
func get_spawn_rotation() -> Vector3:
	return Vector3(0, deg_to_rad(spawn_facing_degrees), 0)
