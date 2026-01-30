extends Node

var time_passed = 0
@onready var timestamp_label: Label = get_node("GUI/BasicOverlay/TimestampLabel")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.game_resumed.connect(_on_game_resumed)

	# Register debug commands
	DebugConsole.register_command("timescale", "Set time scale: /timescale <multiplier>")
	DebugConsole.command_entered.connect(_on_debug_command)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	time_passed += delta
	timestamp_label.text = str(time_passed).pad_decimals(2)
		

func _on_game_paused() -> void:
	get_tree().paused = true

func _on_game_resumed() -> void:
	get_tree().paused = false


## Handle debug console commands
func _on_debug_command(cmd: String, args: PackedStringArray) -> void:
	match cmd:
		"timescale":
			if args.size() > 0:
				Engine.time_scale = float(args[0])
				DebugConsole.debug_log("Timescale set to " + str(Engine.time_scale))
			else:
				DebugConsole.debug_warn("Usage: /timescale <multiplier>")
