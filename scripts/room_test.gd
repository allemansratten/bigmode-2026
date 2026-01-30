extends Node3D

## Test scene for room system development

@onready var player: CharacterBody3D = $Player


func _ready() -> void:
	print("=== RoomTest _ready() started ===")

	# Listen for room transitions to reposition player
	SceneManager.room_transition_completed.connect(_on_room_loaded)

	# Initialize SceneManager with this node as the room container
	print("RoomTest: calling SceneManager.setup()")
	SceneManager.setup(self)

	# Load the initial room (ExampleRoom) - defer to next frame to ensure scene tree is ready
	print("RoomTest: about to load initial room")
	call_deferred("_load_initial_room")


func _load_initial_room() -> void:
	print("RoomTest: calling transition_to_room()")
	SceneManager.transition_to_room(SceneManager.Room.EXAMPLE_ROOM)
	print("RoomTest: transition_to_room() call completed")


func _input(event: InputEvent) -> void:
	# Test item spawning with I key
	if event is InputEventKey and event.pressed and event.keycode == KEY_I:
		_test_spawn_item()


func _test_spawn_item() -> void:
	if not SceneManager.current_room:
		print("RoomTest: no current room")
		return

	var spawner = SceneManager.current_room.get_node_or_null("ItemSpawningManager") as ItemSpawningManager
	if not spawner:
		print("RoomTest: no ItemSpawningManager found in room")
		return

	print("RoomTest: spawning item...")
	var item = spawner.spawn_item()
	if item:
		print("RoomTest: successfully spawned ", item.name)
	else:
		print("RoomTest: failed to spawn item")


func _on_room_loaded(room: Node3D) -> void:
	print("=== RoomTest: _on_room_loaded() called ===")
	print("RoomTest: room = ", room)

	if not room:
		push_error("RoomTest: room is null!")
		return

	# Find a connector to spawn the player at (if available)
	var connectors = room.find_children("Connector*", "RoomConnector", false, false)
	print("RoomTest: found ", connectors.size(), " connector(s)")

	if connectors.size() > 0:
		var spawn_connector = connectors[0] as RoomConnector
		player.global_position = spawn_connector.get_spawn_position()
		player.rotation = spawn_connector.get_spawn_rotation()
		print("RoomTest: spawned player at connector '", spawn_connector.connector_id, "' pos=", player.global_position)
	else:
		# Default spawn at room center
		player.global_position = Vector3(0, 0.5, 0)
		print("RoomTest: spawned player at room center pos=", player.global_position)
