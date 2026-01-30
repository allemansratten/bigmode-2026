extends Node

## Auto-discovers and registers enemy scenes by their enemy_name property
## Similar to ItemRegistry, provides centralized enemy management

var enemies: Dictionary = {}  # enemy_name -> PackedScene


func _ready():
	_discover_enemies()
	print("EnemyRegistry: Discovered %d enemy types" % enemies.size())


## Auto-discover all enemy scenes in the enemies folder
func _discover_enemies():
	enemies.clear()
	var enemy_dir := "res://scenes/enemies/"

	var dir := DirAccess.open(enemy_dir)
	if not dir:
		push_error("Failed to open enemies directory: " + enemy_dir)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tscn"):
			var scene_path := enemy_dir + file_name
			var scene := load(scene_path) as PackedScene

			if scene:
				# Instantiate to get enemy_name
				var instance := scene.instantiate()
				if instance and instance.has_method("get_enemy_name"):
					var enemy_name: String = instance.get_enemy_name()
					if enemy_name != "":
						enemies[enemy_name] = scene
						print("  Registered enemy: '%s' from %s" % [enemy_name, file_name])
					else:
						push_warning("Enemy scene %s has empty enemy_name" % file_name)
				else:
					push_warning("Enemy scene %s doesn't have get_enemy_name() method" % file_name)
				instance.queue_free()

		file_name = dir.get_next()

	dir.list_dir_end()


## Get enemy scene by name
func get_enemy(enemy_name: String) -> PackedScene:
	if enemies.has(enemy_name):
		return enemies[enemy_name]
	push_warning("Enemy '%s' not found in registry" % enemy_name)
	return null


## Get all registered enemy names
func get_all_enemy_names() -> Array[String]:
	var names: Array[String] = []
	names.assign(enemies.keys())
	return names


## Check if enemy exists in registry
func has_enemy(enemy_name: String) -> bool:
	return enemies.has(enemy_name)
