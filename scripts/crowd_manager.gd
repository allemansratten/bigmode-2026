extends Node3D
class_name CrowdManager

## Manages all crowd members in a room
## Contains multiple spawn zones (PeopleSpawner) as children
## Handles shared crowd behaviors and coordination

## Reference to all spawn zones
var spawn_zones: Array[PeopleSpawner] = []

## All active crowd members across all zones
var all_crowd_members: Array[Node3D] = []


func _ready() -> void:
	# Find all spawn zones (PeopleSpawner children)
	_gather_spawn_zones()

	# Connect to spawn zone signals if needed
	for zone in spawn_zones:
		zone.crowd_spawned.connect(_on_zone_spawned)


func _gather_spawn_zones() -> void:
	"""Collects all PeopleSpawner children"""
	spawn_zones.clear()
	for child in get_children():
		if child is PeopleSpawner:
			spawn_zones.append(child)


func spawn_all_zones() -> void:
	"""Triggers spawning in all zones"""
	for zone in spawn_zones:
		zone.spawn_crowd()


func clear_all_zones() -> void:
	"""Clears all crowd members from all zones"""
	for zone in spawn_zones:
		zone.clear_crowd()
	all_crowd_members.clear()


func _on_zone_spawned(_zone: PeopleSpawner, members: Array[Node3D]) -> void:
	"""Called when a zone finishes spawning its crowd"""
	all_crowd_members.append_array(members)


func get_crowd_count() -> int:
	"""Returns total number of crowd members across all zones"""
	return all_crowd_members.size()


func get_zone_count() -> int:
	"""Returns number of spawn zones"""
	return spawn_zones.size()
