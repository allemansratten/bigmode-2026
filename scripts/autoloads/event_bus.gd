extends Node


# Define global signals here
signal level_started(level_name: String)
signal game_paused()
signal game_resumed()

# Combat signals (for upgrade triggers)
signal enemy_killed(enemy: Node3D, killer: Node3D)
signal enemy_spawned(enemy: Node3D)
signal damage_dealt(target: Node3D, amount: float, source: Node3D)
signal damage_taken(target: Node3D, amount: float, source: Node3D)

# Weapon signals (for upgrade triggers)
signal weapon_thrown(weapon: Node3D, direction: Vector3, from_crowd: bool)
signal weapon_broken(weapon: Node3D)
signal weapon_spawned(weapon: Node3D)
signal weapon_attacked(weapon: Node3D)

# Movement signals (for upgrade triggers)
signal player_dashed(direction: Vector3)
signal player_teleported(from_position: Vector3, to_position: Vector3)

# Item signals (for upgrade triggers)
signal item_picked_up(item: Node3D, picker: Node3D)
signal item_dropped(item: Node3D)

# Room signals (for upgrade triggers)
signal room_entered(room: Node3D)
signal room_cleared(room: Node3D)

# Crowd signals (for upgrade effects)
signal crowd_throw_requested(categories: Array)


# Example: Emit this signal when a new level starts
func start_level(level_name: String) -> void:
	level_started.emit(level_name)

# Emit when the game is paused
func emit_game_paused() -> void:
	game_paused.emit()

# Emit when the game is resumed
func emit_game_resumed() -> void:
	game_resumed.emit()
