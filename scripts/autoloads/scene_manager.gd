extends Node

## Global scene manager for room transitions and scene loading
## Access via SceneManager singleton

## Room identifiers (add new rooms here)
enum Room {
	EXAMPLE_ROOM,
	EXAMPLE_ROOM_2,
}

## Mapping of room enum to scene path
const ROOM_SCENES = {
	Room.EXAMPLE_ROOM: "res://scenes/rooms/ExampleRoom.tscn",
	Room.EXAMPLE_ROOM_2: "res://scenes/rooms/ExampleRoom2.tscn",
}

## Emitted when a room transition starts
signal room_transition_started(from_room: Node3D, to_room: Node3D)
## Emitted when a room transition completes
signal room_transition_completed(room: Node3D)

## Current active room instance
var current_room: Node3D = null

## Parent node where rooms are instantiated (set by game scene)
var room_container: Node3D = null

## Dictionary of loaded rooms by scene path
var loaded_rooms: Dictionary = {}

## Cooldown duration in seconds between room transitions
const TRANSITION_COOLDOWN: float = 1.0

## Whether a transition is currently on cooldown
var is_on_cooldown: bool = false


## Initialize the scene manager with a container for rooms
func setup(container: Node3D) -> void:
	room_container = container
	print("SceneManager: initialized with container ", container.name)

func check_can_transition(room_id):
	if not room_container:
		push_error("SceneManager: room_container not set. Call setup() first.")
		return false

	# Check if on cooldown
	if is_on_cooldown:
		print("SceneManager: transition blocked - on cooldown")
		return false

	# Get room scene path from enum
	if not ROOM_SCENES.has(room_id):
		push_error("SceneManager: unknown room ID ", room_id)
		return false
	return true


## Load and transition to a new room by enum ID
func transition_to_room(room_id: Room) -> void:
	if not check_can_transition(room_id):
		return

	var room_path = ROOM_SCENES[room_id]
	var old_room = current_room

	# Check if room is already loaded
	var new_room: Node3D = null
	if loaded_rooms.has(room_path):
		new_room = loaded_rooms[room_path]
		new_room.visible = true
		new_room.process_mode = Node.PROCESS_MODE_INHERIT
		print("SceneManager: reusing existing room ", new_room.name)
	else:
		# Load and instantiate new room
		var room_scene = load(room_path) as PackedScene
		if not room_scene:
			push_error("SceneManager: failed to load room scene at ", room_path)
			return

		new_room = room_scene.instantiate() as Node3D
		if not new_room:
			push_error("SceneManager: failed to instantiate room scene")
			return

		room_container.add_child(new_room)
		loaded_rooms[room_path] = new_room
		print("SceneManager: instantiated new room ", new_room.name)

	room_transition_started.emit(old_room, new_room)

	# Hide/disable old room instead of removing it (must be deferred)
	if old_room and old_room != new_room:
		old_room.call_deferred("set", "visible", false)
		old_room.call_deferred("set", "process_mode", Node.PROCESS_MODE_DISABLED)

	current_room = new_room

	print("SceneManager: transitioned to room ", new_room.name)
	room_transition_completed.emit(new_room)

	# Start cooldown
	_start_cooldown()



## Reload the current room (for testing/debugging)
func reload_current_room() -> void:
	if not current_room:
		push_warning("SceneManager: no current room to reload")
		return

	var room_scene_path = current_room.scene_file_path
	if room_scene_path.is_empty():
		push_error("SceneManager: current room has no scene_file_path")
		return

	# Find the room ID from the path
	for room_id in ROOM_SCENES:
		if ROOM_SCENES[room_id] == room_scene_path:
			# Remove from cache and reload
			loaded_rooms.erase(room_scene_path)
			transition_to_room(room_id)
			return

	push_error("SceneManager: could not find room ID for path ", room_scene_path)


## Start the transition cooldown
func _start_cooldown() -> void:
	is_on_cooldown = true
	print("SceneManager: cooldown started for ", TRANSITION_COOLDOWN, " seconds")

	await get_tree().create_timer(TRANSITION_COOLDOWN).timeout

	is_on_cooldown = false
	print("SceneManager: cooldown ended")
