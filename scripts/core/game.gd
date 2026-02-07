extends Node3D

var time_passed = 0
@onready var timestamp_label: Label = get_node("GUI/BasicOverlay/TimestampLabel")

@onready var player: CharacterBody3D = $Player
@onready var upgrade_panel: UpgradeSelectionPanel = $GUI/UpgradeSelectionPanel

## Track rooms completed for difficulty/progression
var rooms_completed: int = 0

## Available rooms to pick from (add more as needed)
var available_rooms: Array[SceneManager.Room] = [
	SceneManager.Room.EXAMPLE_ROOM,
	SceneManager.Room.EXAMPLE_ROOM_2,
	SceneManager.Room.EXAMPLE_ROOM_3,
]


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.game_resumed.connect(_on_game_resumed)

	# Listen for room cleared to show upgrade selection
	EventBus.room_cleared.connect(_on_room_cleared)

	# Connect upgrade panel signals
	if upgrade_panel:
		upgrade_panel.upgrade_selected.connect(_on_upgrade_selected)
		upgrade_panel.panel_closed.connect(_on_upgrade_panel_closed)

	# Register debug commands
	DebugConsole.register_command("timescale", "Set time scale: /timescale <multiplier>")
	DebugConsole.register_command("rebakenav", "Manually rebake navigation mesh: /rebakenav")
	DebugConsole.register_command("clearroom", "Simulate room clear: /clearroom")
	DebugConsole.register_command("nextroom", "Skip to next room: /nextroom")
	DebugConsole.command_entered.connect(_on_debug_command)

	print("=== Game _ready() started ===")

	# Listen for room transitions to reposition player
	SceneManager.room_transition_completed.connect(_on_room_loaded)

	# Initialize SceneManager with this node as the room container
	SceneManager.setup(self )

	# Reset upgrades for new run
	UpgradeManager.reset_upgrades()

	# Load the initial room - defer to next frame to ensure scene tree is ready
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
	SceneManager.transition_to_room(SceneManager.Room.EXAMPLE_ROOM_3)


## Called when all waves in a room are cleared
func _on_room_cleared(_room: Node3D) -> void:
	print("Game: Room cleared! Showing upgrade selection...")
	rooms_completed += 1

	# Pause the game
	get_tree().paused = true

	# Show upgrade selection panel
	if upgrade_panel:
		upgrade_panel.show_upgrades()
	else:
		push_error("Game: UpgradeSelectionPanel not found!")
		_transition_to_next_room()


## Called when player selects an upgrade
func _on_upgrade_selected(upgrade_id: String) -> void:
	print("Game: Player selected upgrade: %s" % upgrade_id)

	# Grant the upgrade
	UpgradeManager.grant_upgrade(upgrade_id)

	# Transition to next room
	_transition_to_next_room()


## Called when upgrade panel is closed (with or without selection)
func _on_upgrade_panel_closed() -> void:
	# Resume game
	get_tree().paused = false


## Transition to a random next room
func _transition_to_next_room() -> void:
	# Resume game first
	get_tree().paused = false

	# Pick a random room (excluding current if possible)
	var current_room_id = _get_current_room_id()
	var room_choices = available_rooms.duplicate()

	# Remove current room from choices if we have alternatives
	if room_choices.size() > 1 and current_room_id >= 0:
		room_choices.erase(current_room_id)

	var next_room = room_choices.pick_random()
	print("Game: Transitioning to next room (ID: %d)" % next_room)

	SceneManager.transition_to_room(next_room)


## Get the enum ID of the current room (or -1 if unknown)
func _get_current_room_id() -> int:
	if not SceneManager.current_room:
		return -1

	var room_path = SceneManager.current_room.scene_file_path
	for room_id in SceneManager.ROOM_SCENES:
		if SceneManager.ROOM_SCENES[room_id] == room_path:
			return room_id
	return -1


func _input(event: InputEvent) -> void:
	# Test item spawning with I key
	if event is InputEventKey and event.pressed and event.keycode == KEY_I:
		_test_spawn_item()


func _test_spawn_item() -> void:
	var item_spawner = SceneManager.current_room.get_node_or_null("ItemSpawningManager") as ItemSpawningManager
	item_spawner.spawn_item()


func _on_room_loaded(room: Node3D) -> void:
	print("=== Game: _on_room_loaded() called ===")
	print("Game: room = ", room)

	if not room:
		push_error("Game: room is null!")
		return

	# Set difficulty scaling on the enemy spawner
	var enemy_spawner = room.find_child("EnemySpawner", true, false) as EnemySpawner
	if enemy_spawner:
		enemy_spawner.set_rooms_completed(rooms_completed)
		print("Game: Set spawner difficulty to %d rooms completed" % rooms_completed)

	# Find a connector to spawn the player at (if available)
	var connectors = room.find_children("Connector*", "RoomConnector", false, false)
	print("Game: found ", connectors.size(), " connector(s)")

	if connectors.size() > 0:
		var spawn_connector = connectors[0] as RoomConnector
		player.global_position = spawn_connector.get_spawn_position()
		player.rotation = spawn_connector.get_spawn_rotation()
		print("Game: spawned player at connector '", spawn_connector.connector_id, "' pos=", player.global_position)
	else:
		# Default spawn at room center
		player.global_position = Vector3(0, 0.5, 0)
		print("Game: spawned player at room center pos=", player.global_position)

	if room.name == "ExampleRoom3":
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

		"clearroom":
			DebugConsole.debug_log("Simulating room clear...")
			_on_room_cleared(SceneManager.current_room)

		"nextroom":
			DebugConsole.debug_log("Skipping to next room...")
			_transition_to_next_room()
