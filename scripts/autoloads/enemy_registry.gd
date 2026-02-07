extends Node

## Auto-discovers and registers enemy scenes by their enemy_name property
## Similar to ItemRegistry, provides centralized enemy management
## Also stores threat_level for wave generation

var enemies: Dictionary = {}  # enemy_name -> PackedScene
var threat_levels: Dictionary = {}  # enemy_name -> threat_level (float)

## Static manifest of enemy paths (required for web export - DirAccess doesn't work)
## Add new enemies here when creating them
const ENEMY_PATHS: Array[String] = [
	"res://scenes/enemies/Enemy.tscn",
	"res://scenes/enemies/RangedEnemy.tscn",
]


func _ready():
	_discover_enemies()
	print("EnemyRegistry: Discovered %d enemy types" % enemies.size())


## Register enemies from static manifest
func _discover_enemies():
	enemies.clear()
	threat_levels.clear()

	for scene_path in ENEMY_PATHS:
		var scene := load(scene_path) as PackedScene
		if not scene:
			push_warning("Failed to load enemy scene: " + scene_path)
			continue

		# Instantiate to get enemy_name and threat_level
		var instance := scene.instantiate()
		if instance and instance.has_method("get_enemy_name"):
			var enemy_name: String = instance.get_enemy_name()
			if enemy_name != "":
				enemies[enemy_name] = scene
				# Store threat level (default 10.0 if not set)
				var threat: float = instance.get("threat_level") if instance.get("threat_level") else 10.0
				threat_levels[enemy_name] = threat
				print("  Registered enemy: '%s' (threat: %.1f) from %s" % [enemy_name, threat, scene_path.get_file()])
			else:
				push_warning("Enemy scene %s has empty enemy_name" % scene_path.get_file())
		else:
			push_warning("Enemy scene %s doesn't have get_enemy_name() method" % scene_path.get_file())
		instance.queue_free()


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


## Get threat level for an enemy type
func get_threat_level(enemy_name: String) -> float:
	return threat_levels.get(enemy_name, 10.0)


## Get all enemies sorted by threat level (ascending)
func get_enemies_by_threat() -> Array[String]:
	var sorted_names: Array[String] = []
	sorted_names.assign(enemies.keys())
	sorted_names.sort_custom(func(a, b): return threat_levels.get(a, 10.0) < threat_levels.get(b, 10.0))
	return sorted_names
