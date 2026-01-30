extends Node

var time_passed = 0
@onready var timestamp_label: Label = get_node("GUI/BasicOverlay/TimestampLabel")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.game_resumed.connect(_on_game_resumed)

	# Register debug commands
	DebugConsole.register_command("timescale", "Set time scale: /timescale <multiplier>")
	DebugConsole.register_command("spawn", "Spawn an enemy: /spawn [melee|ranged]")
	DebugConsole.register_command("rebakenav", "Manually rebake navigation mesh: /rebakenav")
	DebugConsole.command_entered.connect(_on_debug_command)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	time_passed += delta
	timestamp_label.text = str(time_passed).pad_decimals(2)
		

func _on_game_paused() -> void:
	get_tree().paused = true

func _on_game_resumed() -> void:
	get_tree().paused = false


####
## Debug commands
####

func _spawn_test_enemy(enemy_type: String = "melee") -> void:
	var current_room = SceneManager.current_room
	if not current_room:
		DebugConsole.debug_warn("No current room")
		return

	var spawner: EnemySpawner = null
	if current_room.has_method("get_enemy_spawner"):
		spawner = current_room.get_enemy_spawner()

	if not spawner:
		DebugConsole.debug_warn("No EnemySpawner in current room")
		return

	var enemy_scene: PackedScene
	match enemy_type:
		"ranged":
			enemy_scene = preload("res://scenes/enemies/RangedEnemy.tscn")
		"melee", _:
			enemy_scene = preload("res://scenes/enemies/Enemy.tscn")

	var enemy = spawner.spawn_at_random_point(enemy_scene)

	if enemy:
		DebugConsole.debug_log("Spawned %s enemy at %s" % [enemy_type, str(enemy.global_position)])
	else:
		DebugConsole.debug_warn("Failed to spawn enemy")


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

		"spawn":
			var enemy_type = "melee"
			if args.size() > 0:
				enemy_type = args[0].to_lower()
			_spawn_test_enemy(enemy_type)

		"rebakenav":
			_rebake_navigation()
