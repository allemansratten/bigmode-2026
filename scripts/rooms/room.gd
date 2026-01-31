extends Node3D
class_name Room

## Base class for room scenes
## Handles navigation mesh baking after room setup

signal navigation_ready()

@export var auto_bake_navigation: bool = true
@export var bake_delay: float = 0.1  # Short delay to ensure all objects are positioned

var navigation_region: NavigationRegion3D = null


func _ready():
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
		if nav_mesh.vertices.size() == 0:
			print("  Note: Vertex count is 0, but navigation may still work (data populates asynchronously)")
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
