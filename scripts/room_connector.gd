extends Area3D
class_name RoomConnector

## Bidirectional connector for entering/exiting rooms
## Detects player interaction and triggers room transition

## Target room ID to transition to (from SceneManager.Room enum)
@export var target_room_id: SceneManager.Room = SceneManager.Room.EXAMPLE_ROOM

## Unique identifier for this connector (e.g. "north", "south", "door_1")
@export var connector_id: String = ""

## Direction the player should face when spawning at this connector (in degrees)
@export var spawn_facing_degrees: float = 0.0

## Visual indicator for the connector (optional)
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Set up collision layer/mask for player detection
	collision_layer = 0  # Don't exist in any layer
	collision_mask = 1   # Detect layer 1 (player)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	print("RoomConnector '%s': player entered, transitioning to room %d" % [connector_id, target_room_id])
	SceneManager.transition_to_room(target_room_id, connector_id)


## Get the spawn position for a player entering through this connector
func get_spawn_position() -> Vector3:
	return global_position


## Get the spawn rotation for a player entering through this connector
func get_spawn_rotation() -> Vector3:
	return Vector3(0, deg_to_rad(spawn_facing_degrees), 0)
