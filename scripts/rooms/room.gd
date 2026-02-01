extends Node3D
class_name Room

## Base class for room scenes
## Handles navigation mesh baking after room setup

signal navigation_ready()

@export var auto_bake_navigation: bool = true
@export var bake_delay: float = 0.1  # Short delay to ensure all objects are positioned

var navigation_region: NavigationRegion3D = null
var active_surfaces: Array[Surface] = []  # All surfaces currently in this room


func _ready():
	# Add to room group for easy lookup
	add_to_group("room")

	# Find NavigationRegion3D in children
	navigation_region = _find_navigation_region(self)

	if auto_bake_navigation and navigation_region:
		# Bake after a short delay to ensure all spawned objects are in place
		await get_tree().create_timer(bake_delay).timeout
		bake_navigation()
	else:
		push_warning("Room %s has no NavigationRegion3D to bake" % name)


func _find_navigation_region(node: Node) -> NavigationRegion3D:
	if node is NavigationRegion3D:
		return node
	for child in node.get_children():
		var result = _find_navigation_region(child)
		if result:
			return result
	return null


## Bake the navigation mesh for this room
## Call this after spawning dynamic obstacles (crates, pillars, etc.)
func bake_navigation() -> void:
	if not navigation_region:
		push_warning("Room has no NavigationRegion3D to bake")
		return

	print("Baking navigation mesh for room ", name)
	print("  NavigationRegion3D found at: ", navigation_region.get_path())

	# Bake the navigation mesh
	# Note: This happens synchronously and may take a few frames for complex geometry
	navigation_region.bake_navigation_mesh()

	# Check if bake produced any geometry
	# Note: vertices may show as 0 immediately after baking due to async processing
	var nav_mesh = navigation_region.navigation_mesh
	if nav_mesh:
		print("  NavMesh vertices: ", nav_mesh.vertices.size())
		print("  NavMesh polygons: ", nav_mesh.polygons.size())
	else:
		push_warning("NavigationRegion3D has no NavigationMesh resource!")

	print("Navigation mesh baked")
	navigation_ready.emit()


## Call this when you spawn new obstacles that should block navigation
func rebake_navigation() -> void:
	bake_navigation()


## Get the EnemySpawner in this room (if it exists)
func get_enemy_spawner() -> EnemySpawner:
	return get_node_or_null("EnemySpawner") as EnemySpawner


## Add a surface to this room's active list
func add_surface(surface: Surface) -> void:
	if not active_surfaces.has(surface):
		active_surfaces.append(surface)
		print("Room %s: Added surface %s (total: %d)" % [name, surface.name, active_surfaces.size()])


## Remove a surface from this room's active list
func remove_surface(surface: Surface) -> void:
	var index = active_surfaces.find(surface)
	if index >= 0:
		active_surfaces.remove_at(index)
		print("Room %s: Removed surface %s (total: %d)" % [name, surface.name, active_surfaces.size()])


## Get the top-most surface at a position (highest Y wins)
## Uses center point detection - checks if pos is within surface radius
func get_top_surface_at_position(pos: Vector3) -> Surface:
	var top_surface: Surface = null
	var max_y = -INF

	for surface in active_surfaces:
		# Check XZ distance (2D check, ignore Y)
		var surface_xz = Vector2(surface.global_position.x, surface.global_position.z)
		var pos_xz = Vector2(pos.x, pos.z)
		var distance = surface_xz.distance_to(pos_xz)

		# Is entity center within surface radius?
		if distance <= surface.radius:
			# Is this surface higher than others?
			if surface.global_position.y > max_y:
				top_surface = surface
				max_y = surface.global_position.y

	return top_surface


## Get all surfaces within a radius of a position (for overlap checks)
func get_surfaces_in_radius(pos: Vector3, search_radius: float) -> Array[Surface]:
	var found_surfaces: Array[Surface] = []

	for surface in active_surfaces:
		var surface_xz = Vector2(surface.global_position.x, surface.global_position.z)
		var pos_xz = Vector2(pos.x, pos.z)
		var distance = surface_xz.distance_to(pos_xz)

		# Check if surface overlaps with search radius
		if distance <= (surface.radius + search_radius):
			found_surfaces.append(surface)

	return found_surfaces
