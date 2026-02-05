extends Node3D
class_name EnemySpawner

## Manages enemy spawning at designated points or dropped from above
## Add Marker3D children to define spawn points
## Supports wave-based combat with room clear detection

signal enemy_spawned(enemy: Enemy)
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal room_cleared()

@export var drop_height: float = 5.0 # How high above the spawner to drop enemies from
@export var spawn_area_size: Vector2 = Vector2(10, 10) # Area for random drop spawning
@export var min_distance_from_player: float = 3.0 # Minimum distance from player for spawning

## Wave configuration
@export var total_waves: int = 3
@export var auto_start_waves: bool = true # Start spawning on room transition

## Threat-based wave generation
@export_group("Difficulty Scaling")
@export var base_threat_per_wave: float = 15.0  # Starting threat budget for wave 1
@export var threat_increase_per_wave: float = 10.0  # Additional threat each wave
@export var threat_increase_per_room: float = 5.0  # Additional base threat for each room cleared
@export var threat_variance: float = 0.2  # Random variance (±20%)

var spawn_points: Array[Marker3D] = []
var _alive_enemies: int = 0
var _current_wave: int = 0  # 0 = not started, 1-3 = active wave
var _waves_active: bool = false
var _rooms_completed: int = 0  # Track difficulty progression


func _ready():
	_collect_spawn_points()

	# Wait for room's navigation to be ready before spawning enemies
	var room = _find_room()
	if room and room.has_signal("navigation_ready"):
		if not room.navigation_ready.is_connected(_on_navigation_ready):
			room.navigation_ready.connect(_on_navigation_ready)

	# Listen for room transitions
	SceneManager.room_transition_completed.connect(_on_room_transition_completed)

	# Register debug commands
	_register_commands()


func _exit_tree():
	# Unregister debug commands when spawner is removed
	_unregister_commands()


func _find_room() -> Node:
	var current = get_parent()
	while current:
		if current.has_method("bake_navigation"):
			return current
		current = current.get_parent()
	return null


func _on_navigation_ready() -> void:
	print("EnemySpawner: Navigation ready, can spawn enemies now")


func _on_room_transition_completed(_room: Node3D) -> void:
	if auto_start_waves:
		start_waves()


## Start the wave-based combat sequence
func start_waves() -> void:
	if _waves_active:
		push_warning("Waves already active, ignoring start_waves call")
		return

	_waves_active = true
	_current_wave = 0
	_spawn_next_wave()


## Reset spawner state (for reuse or new room)
func reset() -> void:
	_waves_active = false
	_current_wave = 0
	_alive_enemies = 0


## Get current wave number (1-based, 0 = not started)
func get_current_wave() -> int:
	return _current_wave


## Check if all waves are complete
func is_room_cleared() -> bool:
	return _current_wave > total_waves or (_current_wave == total_waves and _alive_enemies == 0)


func _spawn_next_wave() -> void:
	if _current_wave >= total_waves:
		# All waves complete - room cleared!
		_on_room_complete()
		return

	_current_wave += 1
	wave_started.emit(_current_wave)
	EventBus.wave_started.emit(_current_wave)

	# Calculate threat budget for this wave
	var threat_budget = _calculate_wave_threat(_current_wave)
	print("EnemySpawner: Starting wave %d of %d (threat budget: %.1f)" % [_current_wave, total_waves, threat_budget])

	# Generate and spawn enemies based on threat budget
	var enemies_to_spawn = _generate_wave_enemies(threat_budget)
	for i in range(enemies_to_spawn.size()):
		var enemy_name = enemies_to_spawn[i]
		# Alternate spawn methods for variety
		var method = "dropped" if i % 2 == 0 else "random"
		spawn_enemy_by_name(enemy_name, method)


## Calculate the threat budget for a specific wave
func _calculate_wave_threat(wave_number: int) -> float:
	# Base threat + wave scaling + room scaling
	var base = base_threat_per_wave + (_rooms_completed * threat_increase_per_room)
	var wave_bonus = (wave_number - 1) * threat_increase_per_wave
	var total = base + wave_bonus

	# Apply random variance
	var variance = total * threat_variance
	total += randf_range(-variance, variance)

	return max(total, base_threat_per_wave * 0.5)  # Minimum floor


## Generate a list of enemies to spawn based on threat budget
func _generate_wave_enemies(threat_budget: float) -> Array[String]:
	var enemies_to_spawn: Array[String] = []
	var remaining_threat = threat_budget
	var available_enemies = EnemyRegistry.get_all_enemy_names()

	if available_enemies.is_empty():
		push_error("EnemySpawner: No enemies registered!")
		return enemies_to_spawn

	# Keep adding enemies until we've spent the threat budget
	var iterations = 0
	var max_iterations = 50  # Safety limit

	while remaining_threat > 0 and iterations < max_iterations:
		iterations += 1

		# Find enemies that fit within remaining budget
		var valid_enemies: Array[String] = []
		var min_threat = INF

		for enemy_name in available_enemies:
			var threat = EnemyRegistry.get_threat_level(enemy_name)
			min_threat = min(min_threat, threat)
			if threat <= remaining_threat:
				valid_enemies.append(enemy_name)

		# If no enemies fit, check if we should force spawn the cheapest
		if valid_enemies.is_empty():
			# Only force spawn if we have significant budget left (>50% of min enemy)
			if remaining_threat >= min_threat * 0.5 and enemies_to_spawn.is_empty():
				# Force at least one enemy
				var cheapest = _get_cheapest_enemy(available_enemies)
				enemies_to_spawn.append(cheapest)
			break

		# Pick a random valid enemy
		var chosen_enemy = valid_enemies.pick_random()
		enemies_to_spawn.append(chosen_enemy)
		remaining_threat -= EnemyRegistry.get_threat_level(chosen_enemy)

	print("EnemySpawner: Generated %d enemies for wave" % enemies_to_spawn.size())
	return enemies_to_spawn


## Get the enemy with lowest threat level
func _get_cheapest_enemy(enemy_names: Array[String]) -> String:
	var cheapest = enemy_names[0]
	var lowest_threat = EnemyRegistry.get_threat_level(cheapest)

	for enemy_name in enemy_names:
		var threat = EnemyRegistry.get_threat_level(enemy_name)
		if threat < lowest_threat:
			lowest_threat = threat
			cheapest = enemy_name

	return cheapest


## Set the rooms completed count (for difficulty scaling)
func set_rooms_completed(count: int) -> void:
	_rooms_completed = count
	print("EnemySpawner: Difficulty set to %d rooms completed" % count)


func _on_enemy_died(_enemy: Enemy) -> void:
	_alive_enemies -= 1
	if _alive_enemies <= 0:
		_alive_enemies = 0
		wave_completed.emit(_current_wave)
		print("EnemySpawner: Wave %d completed" % _current_wave)

		if _waves_active:
			# Small delay before next wave for player breathing room
			await get_tree().create_timer(1.5).timeout
			_spawn_next_wave()


func _on_room_complete() -> void:
	_waves_active = false
	print("EnemySpawner: Room cleared! All %d waves complete." % total_waves)

	# Emit local signal
	room_cleared.emit()

	# Emit global EventBus signal for upgrade system and game manager
	var room = _find_room()
	EventBus.room_cleared.emit(room)


## Register debug console commands
func _register_commands() -> void:
	DebugConsole.register_command("spawn", "Spawn an enemy: /spawn <enemy_name>")
	DebugConsole.command_entered.connect(_on_command_entered)


## Unregister debug console commands
func _unregister_commands() -> void:
	if DebugConsole.command_entered.is_connected(_on_command_entered):
		DebugConsole.command_entered.disconnect(_on_command_entered)


## Handle debug commands
func _on_command_entered(cmd: String, args: PackedStringArray) -> void:
	if cmd == "spawn":
		if args.size() > 0:
			_spawn_enemy(args[0].to_lower())
		else:
			var available := EnemyRegistry.get_all_enemy_names()
			DebugConsole.debug_warn("Usage: /spawn <enemy_name>")
			DebugConsole.debug_log("Available enemies: " + ", ".join(available))


## Spawn enemy by name via debug command
func _spawn_enemy(enemy_name: String) -> void:
	if not EnemyRegistry.has_enemy(enemy_name):
		DebugConsole.debug_warn("Unknown enemy type: '%s'" % enemy_name)
		var available := EnemyRegistry.get_all_enemy_names()
		DebugConsole.debug_log("Available enemies: " + ", ".join(available))
		return

	var enemy = spawn_enemy_by_name(enemy_name)

	if enemy:
		DebugConsole.debug_log("Spawned '%s' enemy at %s" % [enemy_name, str(enemy.global_position)])
	else:
		DebugConsole.debug_warn("Failed to spawn enemy")


func _collect_spawn_points():
	spawn_points.clear()
	for child in get_children():
		if child is Marker3D:
			spawn_points.append(child)

	if spawn_points.size() > 0:
		print("EnemySpawner found %d spawn points" % spawn_points.size())


func _get_player() -> Node3D:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null


func _is_position_far_from_player(pos: Vector3) -> bool:
	var player = _get_player()
	if not player:
		return true # No player found, allow spawning anywhere

	# Use XZ distance (ignore height difference)
	var player_pos_xz = Vector2(player.global_position.x, player.global_position.z)
	var spawn_pos_xz = Vector2(pos.x, pos.z)
	return player_pos_xz.distance_to(spawn_pos_xz) >= min_distance_from_player


## Spawns an enemy at a specific spawn point by index
func spawn_at_point(point_index: int, enemy_scene: PackedScene) -> Enemy:
	if point_index < 0 or point_index >= spawn_points.size():
		push_error("Invalid spawn point index: %d (have %d points)" % [point_index, spawn_points.size()])
		return null

	var spawn_point := spawn_points[point_index]
	return _spawn_enemy_at(enemy_scene, spawn_point.global_position)


## Spawns an enemy at a random spawn point (avoiding positions too close to player)
func spawn_at_random_point(enemy_scene: PackedScene) -> Enemy:
	if spawn_points.size() == 0:
		push_error("No spawn points available")
		return null

	# Filter spawn points that are far enough from the player
	var valid_points: Array[int] = []
	for i in range(spawn_points.size()):
		if _is_position_far_from_player(spawn_points[i].global_position):
			valid_points.append(i)

	# If no valid points, fall back to any spawn point with a warning
	if valid_points.size() == 0:
		push_warning("All spawn points are too close to player, using random point anyway")
		var fallback_index := randi() % spawn_points.size()
		return spawn_at_point(fallback_index, enemy_scene)

	var chosen_index := valid_points[randi() % valid_points.size()]
	return spawn_at_point(chosen_index, enemy_scene)


## Spawns an enemy dropped from above at a random location within spawn_area_size
## (avoiding positions too close to player)
func spawn_dropped(enemy_scene: PackedScene) -> Enemy:
	const MAX_ATTEMPTS := 10

	for attempt in range(MAX_ATTEMPTS):
		# Random position within area
		var random_offset := Vector3(
			randf_range(-spawn_area_size.x * 0.5, spawn_area_size.x * 0.5),
			drop_height,
			randf_range(-spawn_area_size.y * 0.5, spawn_area_size.y * 0.5)
		)

		var spawn_pos := global_position + random_offset

		if _is_position_far_from_player(spawn_pos):
			return _spawn_enemy_at(enemy_scene, spawn_pos)

	# Fallback: spawn anyway after max attempts
	push_warning("Could not find spawn position far from player after %d attempts" % MAX_ATTEMPTS)
	var fallback_offset := Vector3(
		randf_range(-spawn_area_size.x * 0.5, spawn_area_size.x * 0.5),
		drop_height,
		randf_range(-spawn_area_size.y * 0.5, spawn_area_size.y * 0.5)
	)
	return _spawn_enemy_at(enemy_scene, global_position + fallback_offset)


## Spawn enemy by name using EnemyRegistry
func spawn_enemy_by_name(enemy_name: String, method: String = "random") -> Enemy:
	var enemy_scene := EnemyRegistry.get_enemy(enemy_name)
	if not enemy_scene:
		push_error("Failed to get enemy '%s' from registry" % enemy_name)
		return null

	match method:
		"random":
			return spawn_at_random_point(enemy_scene)
		"dropped":
			return spawn_dropped(enemy_scene)
		_:
			push_warning("Unknown spawn method: %s, using random" % method)
			return spawn_at_random_point(enemy_scene)


func _spawn_enemy_at(enemy_scene: PackedScene, spawn_position: Vector3) -> Enemy:
	if not enemy_scene:
		push_error("No enemy scene provided")
		return null

	var enemy := enemy_scene.instantiate() as Enemy
	if not enemy:
		push_error("Scene is not an Enemy")
		return null

	# Add to scene tree
	get_parent().add_child(enemy)
	enemy.global_position = spawn_position

	# Track alive enemies
	_alive_enemies += 1
	enemy.died.connect(_on_enemy_died)

	enemy_spawned.emit(enemy)

	# Emit global event for upgrade system
	EventBus.enemy_spawned.emit(enemy)

	return enemy
