extends Node3D
class_name CrowdManager

## Manages all crowd members in a room
## Contains multiple spawn zones (PeopleSpawner) as children
## Handles shared crowd behaviors and coordination

## Emitted when excitement level changes
signal excitement_changed(new_level: float)

## Rate at which excitement decays per second
@export var decay_rate: float = 5.0

## Current excitement level (0-100)
var excitement_level: float = 0.0:
	set(value):
		var old_level := excitement_level
		excitement_level = clampf(value, 0.0, 100.0)
		if not is_equal_approx(old_level, excitement_level):
			excitement_changed.emit(excitement_level)

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


func _process(delta: float) -> void:
	# Decay excitement towards 0
	if excitement_level > 0.0:
		excitement_level -= decay_rate * delta

	# Handle input for excitement increase
	if Input.is_action_just_pressed("increase_excitement"):
		increase_excitement(20.0)


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


func increase_excitement(amount: float) -> void:
	"""Increases excitement level by the given amount"""
	excitement_level += amount


func set_excitement(value: float) -> void:
	"""Sets excitement level to a specific value"""
	excitement_level = value
