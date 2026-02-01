extends Node3D
class_name EnemySpawner

## Manages enemy spawning at designated points or dropped from above
## Add Marker3D children to define spawn points

signal enemy_spawned(enemy: Enemy)

@export var drop_height: float = 5.0 # How high above the spawner to drop enemies from
@export var spawn_area_size: Vector2 = Vector2(10, 10) # Area for random drop spawning

var spawn_points: Array[Marker3D] = []


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
	# TODO: wave management
	_spawn_enemy("melee")


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


## Spawns an enemy at a specific spawn point by index
func spawn_at_point(point_index: int, enemy_scene: PackedScene) -> Enemy:
	if point_index < 0 or point_index >= spawn_points.size():
		push_error("Invalid spawn point index: %d (have %d points)" % [point_index, spawn_points.size()])
		return null

	var spawn_point := spawn_points[point_index]
	return _spawn_enemy_at(enemy_scene, spawn_point.global_position)


## Spawns an enemy at a random spawn point
func spawn_at_random_point(enemy_scene: PackedScene) -> Enemy:
	if spawn_points.size() == 0:
		push_error("No spawn points available")
		return null

	var random_index := randi() % spawn_points.size()
	return spawn_at_point(random_index, enemy_scene)


## Spawns an enemy dropped from above at a random location within spawn_area_size
func spawn_dropped(enemy_scene: PackedScene) -> Enemy:
	# Random position within area
	var random_offset := Vector3(
		randf_range(-spawn_area_size.x * 0.5, spawn_area_size.x * 0.5),
		drop_height,
		randf_range(-spawn_area_size.y * 0.5, spawn_area_size.y * 0.5)
	)

	var spawn_pos := global_position + random_offset
	return _spawn_enemy_at(enemy_scene, spawn_pos)


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

	enemy_spawned.emit(enemy)

	return enemy
