@tool
extends Node3D
class_name PeopleSpawner

## Spawns NPCs in a defined rectangular area (spawn zone)
## Managed by CrowdManager parent node
## Each zone handles its own crowd member placement and spawning

## Emitted when crowd spawning is complete
signal crowd_spawned(zone: PeopleSpawner, members: Array[Node3D])

## The rectangular spawn area dimensions
@export var spawn_area_size: Vector2 = Vector2(8, 6):
	set(value):
		spawn_area_size = value
		update_gizmos()

## Spacing between NPCs
@export var spacing: float = 1.0

## Height offset for spawning NPCs
@export var spawn_height: float = 0.0:
	set(value):
		spawn_height = value
		update_gizmos()

## Optional: NPC scene to spawn (uses CrowdMember by default)
@export var npc_scene: PackedScene = null

## Debug visualization color
@export var debug_color: Color = Color.YELLOW

## Add random position offset to prevent grid look
@export var random_offset: float = 0.2

## Add random rotation variation
@export var random_rotation: bool = true

## Auto-spawn on ready
@export var auto_spawn: bool = true

var _spawned_members: Array[Node3D] = []


func _ready() -> void:
	# Only spawn in game, not in editor
	if not Engine.is_editor_hint() and auto_spawn:
		spawn_crowd()


func spawn_crowd() -> void:
	"""Spawns NPCs in the defined area using Poisson Disc Sampling"""
	# Clear existing crowd members first
	clear_crowd()

	# Load the NPC scene (default to CrowdMember)
	var scene := npc_scene
	if scene == null:
		scene = load("res://scenes/crowd/CrowdMember.tscn")

	if scene == null:
		push_error("PeopleSpawner: No NPC scene available to spawn")
		return

	# Generate spawn positions using Poisson Disc Sampling
	var positions := _poisson_disc_sampling(spawn_area_size, spacing)

	# Spawn NPCs at each position
	for pos_2d in positions:
		var spawn_pos := Vector3(pos_2d.x, spawn_height, pos_2d.y)

		# Instantiate the NPC
		var npc := scene.instantiate() as Node3D
		if npc == null:
			continue

		add_child(npc)
		npc.position = spawn_pos

		# Add random rotation if enabled
		if random_rotation:
			npc.rotation.y = randf_range(0, TAU)

		# Set variation seed if it's a CrowdMember
		if npc.has_method("set"):
			npc.set("variation_seed", randi())

		_spawned_members.append(npc)

	# Notify manager that spawning is complete
	crowd_spawned.emit(self, _spawned_members)


func _poisson_disc_sampling(area_size: Vector2, min_distance: float, max_attempts: int = 30) -> Array[Vector2]:
	"""
	Generates points using Poisson Disc Sampling (Bridson's algorithm)
	Returns points distributed with minimum distance between them for natural spacing

	area_size: The dimensions of the rectangular area
	min_distance: Minimum distance between any two points (spacing)
	max_attempts: Number of attempts to place a point around each sample
	"""
	var points: Array[Vector2] = []
	var active_list: Array[Vector2] = []

	# Grid for fast spatial lookup
	var cell_size := min_distance / sqrt(2.0)
	var grid_width := int(ceil(area_size.x / cell_size))
	var grid_height := int(ceil(area_size.y / cell_size))
	var grid: Array = []
	grid.resize(grid_width * grid_height)

	# Helper to get grid index
	var get_grid_index = func(point: Vector2) -> int:
		var gx := int((point.x + area_size.x / 2.0) / cell_size)
		var gy := int((point.y + area_size.y / 2.0) / cell_size)
		return gy * grid_width + gx

	# Helper to check if point is valid
	var is_valid_point = func(point: Vector2) -> bool:
		# Check if within bounds
		if abs(point.x) > area_size.x / 2.0 or abs(point.y) > area_size.y / 2.0:
			return false

		# Check distance to nearby points using grid
		var gx := int((point.x + area_size.x / 2.0) / cell_size)
		var gy := int((point.y + area_size.y / 2.0) / cell_size)

		# Check neighboring cells
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var ngx := gx + dx
				var ngy := gy + dy

				if ngx < 0 or ngx >= grid_width or ngy < 0 or ngy >= grid_height:
					continue

				var grid_idx := ngy * grid_width + ngx
				if grid[grid_idx] != null:
					var neighbor: Vector2 = grid[grid_idx]
					if point.distance_to(neighbor) < min_distance:
						return false

		return true

	# Start with initial point at center
	var initial_point := Vector2(
		randf_range(-area_size.x / 4.0, area_size.x / 4.0),
		randf_range(-area_size.y / 4.0, area_size.y / 4.0)
	)

	points.append(initial_point)
	active_list.append(initial_point)
	grid[get_grid_index.call(initial_point)] = initial_point

	# Process active list
	while active_list.size() > 0:
		# Pick random point from active list
		var random_index := randi() % active_list.size()
		var point := active_list[random_index]
		var found_valid := false

		# Try to place new points around this point
		for _attempt in range(max_attempts):
			# Generate random point in annulus between min_distance and 2*min_distance
			var angle := randf_range(0, TAU)
			var radius := randf_range(min_distance, min_distance * 2.0)
			var new_point := point + Vector2(cos(angle), sin(angle)) * radius

			if is_valid_point.call(new_point):
				points.append(new_point)
				active_list.append(new_point)
				grid[get_grid_index.call(new_point)] = new_point
				found_valid = true

		# If no valid point found, remove from active list
		if not found_valid:
			active_list.remove_at(random_index)

	return points


func clear_crowd() -> void:
	"""Removes all spawned crowd members"""
	for member in _spawned_members:
		if is_instance_valid(member):
			member.queue_free()
	_spawned_members.clear()
