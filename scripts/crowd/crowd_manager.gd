extends Node3D
class_name CrowdManager

## Manages all crowd members in a room
## Contains multiple spawn zones (PeopleSpawner) as children
## Handles shared crowd behaviors and coordination

## Emitted when excitement level changes
signal excitement_changed(new_level: float)

## Rate at which excitement decays per second
@export var decay_rate: float = 1.0

## Item throw timer settings
@export var throw_interval: float = 3.0 ## Seconds between throw attempts
@export var min_throw_chance: float = 0.05 ## Chance at 0 excitement (5%)
@export var max_throw_chance: float = 0.8 ## Chance at 100 excitement (80%)

## Wave start weapon throws
@export var wave_start_weapon_count: int = 2 ## Number of weapons to throw at wave start

## Enemy spawn excitement
@export var enemy_spawn_excitement_multiplier: float = 0.2 ## 20% of enemy threat level

var _throw_timer: Timer
var _decay_timer: Timer

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
	# Add to group so upgrade effects can find us
	add_to_group("crowd_manager")

	# Find all spawn zones (PeopleSpawner children)
	_gather_spawn_zones()

	# Connect to spawn zone signals if needed
	for zone in spawn_zones:
		zone.crowd_spawned.connect(_on_zone_spawned)

	# Setup item throw timer
	_throw_timer = Timer.new()
	_throw_timer.name = "ThrowTimer"
	_throw_timer.wait_time = throw_interval
	_throw_timer.one_shot = false
	_throw_timer.timeout.connect(_on_throw_timer_timeout)
	add_child(_throw_timer)
	_throw_timer.start()

	# Setup excitement decay timer
	_decay_timer = Timer.new()
	_decay_timer.name = "DecayTimer"
	_decay_timer.wait_time = 1 ## Check decay every 1 second
	_decay_timer.one_shot = false
	_decay_timer.timeout.connect(_on_decay_timer_timeout)
	add_child(_decay_timer)
	_decay_timer.start()

	# Connect to wave and enemy spawn events
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.enemy_spawned.connect(_on_enemy_spawned)


func _unhandled_input(event: InputEvent) -> void:
	# Debug input to increase excitement
	if event.is_action_pressed("increase_excitement"):
		increase_excitement(20.0)

## Decay excitement towards 0 over time
func _on_decay_timer_timeout() -> void:
	if excitement_level > 0.0:
		excitement_level -= decay_rate * _decay_timer.wait_time

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


func _on_throw_timer_timeout() -> void:
	"""Attempts to throw an item based on excitement level"""
	# Calculate throw chance based on excitement (linear interpolation)
	var normalized_excitement := excitement_level / 100.0
	var throw_chance := lerpf(min_throw_chance, max_throw_chance, normalized_excitement)

	# Roll for throw
	if randf() < throw_chance:
		# Request crowd throw via EventBus (empty array = use room defaults)
		EventBus.crowd_throw_requested.emit([])


func _on_wave_started(_wave_number: int) -> void:
	"""Throw weapons at the start of each wave to ensure player has something to fight with"""
	for i in range(wave_start_weapon_count):
		# Request weapon throw with WEAPON category filter
		EventBus.crowd_throw_requested.emit([ItemCategories.Category.WEAPON])


func _on_enemy_spawned(enemy: Node3D) -> void:
	"""Increase crowd excitement when an enemy spawns"""
	var threat: float = enemy.get("threat_level") if enemy.get("threat_level") else 10.0
	var excitement_increase := threat * enemy_spawn_excitement_multiplier
	increase_excitement(excitement_increase)
