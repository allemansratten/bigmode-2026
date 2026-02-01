extends Node3D

var time_passed = 0
@onready var timestamp_label: Label = get_node("GUI/BasicOverlay/TimestampLabel")

@onready var player: CharacterBody3D = $Player


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.game_resumed.connect(_on_game_resumed)

	# Register debug commands
	DebugConsole.register_command("timescale", "Set time scale: /timescale <multiplier>")
	DebugConsole.register_command("rebakenav", "Manually rebake navigation mesh: /rebakenav")
	DebugConsole.command_entered.connect(_on_debug_command)

	print("=== RoomTest _ready() started ===")

	# Listen for room transitions to reposition player
	SceneManager.room_transition_completed.connect(_on_room_loaded)

	# Initialize SceneManager with this node as the room container
	SceneManager.setup(self )

	# Load the initial room (ExampleRoom) - defer to next frame to ensure scene tree is ready
	_load_initial_room.call_deferred()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	time_passed += delta
	timestamp_label.text = str(time_passed).pad_decimals(2)
		

func _on_game_paused() -> void:
	get_tree().paused = true

func _on_game_resumed() -> void:
	get_tree().paused = false


func _load_initial_room() -> void:
	SceneManager.transition_to_room(SceneManager.Room.EXAMPLE_ROOM)


func _input(event: InputEvent) -> void:
	# Test item spawning with I key
	if event is InputEventKey and event.pressed and event.keycode == KEY_I:
		_test_spawn_item()


func _test_spawn_item() -> void:
	var item_spawner = SceneManager.current_room.get_node_or_null("ItemSpawningManager") as ItemSpawningManager
	item_spawner.spawn_item()


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

	if room.name == "ExampleRoom":
		_test_spawn_item()
		_test_spawn_item()
		_test_spawn_item()


####
## Debug commands
####

func _rebake_navigation() -> void:
	var current_room = SceneManager.current_room
	if not current_room:
		DebugConsole.debug_warn("No current room")
		return

	if current_room.has_method("bake_navigation"):
		DebugConsole.debug_log("Rebaking navigation...")
		current_room.bake_navigation()
	else:
		DebugConsole.debug_warn("Current room doesn't support navigation baking")


## Handle debug console commands
func _on_debug_command(cmd: String, args: PackedStringArray) -> void:
	match cmd:
		"timescale":
			if args.size() > 0:
				Engine.time_scale = float(args[0])
				DebugConsole.debug_log("Timescale set to " + str(Engine.time_scale))
			else:
				DebugConsole.debug_warn("Usage: /timescale <multiplier>")

		"rebakenav":
			_rebake_navigation()
