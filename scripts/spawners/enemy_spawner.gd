extends Node3D
class_name EnemySpawner

## Manages enemy spawning at designated points or dropped from above
## Add Marker3D children to define spawn points

signal enemy_spawned(enemy: Enemy)

@export var drop_height: float = 5.0  # How high above the spawner to drop enemies from
@export var spawn_area_size: Vector2 = Vector2(10, 10)  # Area for random drop spawning

var spawn_points: Array[Marker3D] = []


func _ready():
	_collect_spawn_points()


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
