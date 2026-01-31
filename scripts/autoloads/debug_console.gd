extends Node

## Debug Console - Command parsing and execution system
## Parses slash commands and emits signals for other systems to handle
## Built-in commands are handled directly, custom commands emit signals
##
## Usage in other scripts:
## ```
## func _ready():
##     DebugConsole.command_entered.connect(_on_debug_command)
##
## func _on_debug_command(cmd: String, args: PackedStringArray):
##     match cmd:
##         "health":
##             health = int(args[0])
##             DebugConsole.debug_log("Health set to " + str(health))
## ```

## Emitted when a custom command is entered
## Built-in commands (clear, help) are handled internally
signal command_entered(command: String, args: PackedStringArray)

## Command registry for help text and validation
var _registered_commands: Dictionary = {}

## Command history for UI navigation
var _command_history: Array[String] = []
var _max_history: int = 50

## Console output log
var _log_entries: Array[Dictionary] = []
var _max_log_size: int = 100

enum LogLevel { INFO, WARNING, ERROR }

## UI references
@onready var _ui_panel: Panel = $UI/Panel
@onready var _output_log: RichTextLabel = $UI/Panel/MarginContainer/VBoxContainer/ScrollContainer/OutputLog
@onready var _input_line: LineEdit = $UI/Panel/MarginContainer/VBoxContainer/InputLine

## Command history navigation
var _history_index: int = -1


func _ready():
	# Register built-in commands
	register_command("help", "Show available commands")
	register_command("clear", "Clear console output")

	debug_log("Debug Console initialized. Type /help for commands.")


## Handle input for toggling console and command history
func _input(event: InputEvent) -> void:
	# Toggle console with tilde key
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_QUOTELEFT:  # Tilde/backtick key
			toggle_console()
			get_viewport().set_input_as_handled()

	# Command history navigation (only when console is open)
	if _ui_panel.visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_UP:
			_navigate_history(-1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN:
			_navigate_history(1)
			get_viewport().set_input_as_handled()


## Toggle console visibility
func toggle_console() -> void:
	_ui_panel.visible = !_ui_panel.visible

	if _ui_panel.visible:
		_input_line.grab_focus()
		_history_index = -1
	else:
		_input_line.release_focus()


## Navigate command history
func _navigate_history(direction: int) -> void:
	if _command_history.is_empty():
		return

	_history_index = clamp(_history_index + direction, -1, _command_history.size() - 1)

	if _history_index == -1:
		_input_line.text = ""
	else:
		_input_line.text = _command_history[_command_history.size() - 1 - _history_index]
		_input_line.caret_column = _input_line.text.length()


## Handle text submission from input line
func _on_input_line_text_submitted(text: String) -> void:
	if not text.is_empty():
		process_input(text)
		_input_line.clear()
		_history_index = -1


## Register a command for documentation and autocomplete
## This is optional - commands work without registration via signal
func register_command(command: String, description: String = "") -> void:
	_registered_commands[command] = description


## Process a raw input string from the console
func process_input(input: String) -> void:
	if input.is_empty():
		return

	# Add to history
	_command_history.append(input)
	if _command_history.size() > _max_history:
		_command_history.pop_front()

	# Parse command
	if not input.begins_with("/"):
		debug_warn("Commands must start with /")
		return

	var parts = _parse_command(input.substr(1))  # Remove leading /
	if parts.is_empty():
		return

	var command = parts[0]
	var args = PackedStringArray()
	for i in range(1, parts.size()):
		args.append(parts[i])

	# Log the command
	debug_log("> " + input)

	# Handle built-in commands
	if _handle_builtin_command(command, args):
		return

	# Emit signal for custom commands
	command_entered.emit(command, args)


## Parse command string into parts, respecting quotes
func _parse_command(input: String) -> PackedStringArray:
	var parts: PackedStringArray = []
	var current_part = ""
	var in_quotes = false
	var i = 0

	while i < input.length():
		var c = input[i]

		if c == '"':
			in_quotes = !in_quotes
		elif c == ' ' and not in_quotes:
			if not current_part.is_empty():
				parts.append(current_part)
				current_part = ""
		else:
			current_part += c

		i += 1

	# Add final part
	if not current_part.is_empty():
		parts.append(current_part)

	return parts


## Handle built-in commands
## Returns true if command was handled, false otherwise
func _handle_builtin_command(command: String, _args: PackedStringArray) -> bool:
	match command:
		"help":
			_show_help()
			return true

		"clear":
			_log_entries.clear()
			_output_log.clear()
			debug_log("Console cleared")
			return true

	return false


## Show help text with all registered commands
func _show_help() -> void:
	debug_log("Available commands:")

	for cmd in _registered_commands.keys():
		var desc = _registered_commands[cmd]
		if desc.is_empty():
			debug_log("  /" + cmd)
		else:
			debug_log("  /" + cmd + " - " + desc)


## Add an info message to the console log
func debug_log(message: String) -> void:
	_add_to_log(message, LogLevel.INFO)


## Add a warning message to the console log
func debug_warn(message: String) -> void:
	_add_to_log(message, LogLevel.WARNING)


## Add an error message to the console log
func debug_error(message: String) -> void:
	_add_to_log(message, LogLevel.ERROR)


## Internal: Add message to log with level
func _add_to_log(message: String, level: LogLevel) -> void:
	_log_entries.append({
		"message": message,
		"level": level,
		"timestamp": Time.get_ticks_msec()
	})

	# Trim log if too large
	if _log_entries.size() > _max_log_size:
		_log_entries.pop_front()

	# Update UI log with color coding
	_update_ui_log(message, level)

	# Also print to Godot console for development
	match level:
		LogLevel.INFO:
			print("[DebugConsole] ", message)
		LogLevel.WARNING:
			push_warning("[DebugConsole] " + message)
		LogLevel.ERROR:
			push_error("[DebugConsole] " + message)


## Update the UI RichTextLabel with colored message
func _update_ui_log(message: String, level: LogLevel) -> void:
	var color_code = ""
	match level:
		LogLevel.INFO:
			color_code = "[color=white]"
		LogLevel.WARNING:
			color_code = "[color=yellow]"
		LogLevel.ERROR:
			color_code = "[color=red]"

	_output_log.append_text(color_code + message + "[/color]\n")


## Get command history for UI navigation
func get_command_history() -> Array[String]:
	return _command_history


## Get output log for UI display
func get_output_log() -> Array[Dictionary]:
	return _log_entries
