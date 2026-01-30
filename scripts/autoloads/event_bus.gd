extends Node


# Define global signals here
signal level_started(level_name: String)
signal game_paused()
signal game_resumed()


# Example: Emit this signal when a new level starts
func start_level(level_name: String) -> void:
	level_started.emit(level_name)

# Emit when the game is paused
func emit_game_paused() -> void:
	game_paused.emit()

# Emit when the game is resumed
func emit_game_resumed() -> void:
	game_resumed.emit()
