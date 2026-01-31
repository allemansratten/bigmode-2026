extends OnDestroyEffect
class_name SpawnSurfaceEffect

## Spawns a surface (oil, ice, water) when this weapon is destroyed
## Useful for flasks, grenades, or environmental weapons

@export var surface_scene: PackedScene
@export var spawn_offset: Vector3 = Vector3(0, 0.05, 0)  # Slight Y offset to sit on ground


func execute() -> void:
	if not surface_scene:
		push_warning("SpawnSurfaceEffect: No surface_scene assigned!")
		return

	# Find the room to spawn the surface in
	var room = get_tree().get_first_node_in_group("room")
	if not room:
		push_warning("SpawnSurfaceEffect: No room found to spawn surface in!")
		return

	# Get spawn position from parent item (item is Node3D, weapon is just Node)
	var spawn_position = item.global_position + spawn_offset

	# Instance and spawn the surface
	var surface = surface_scene.instantiate()

	# Add to room first (surface needs to be in tree before setting global_position)
	room.add_child(surface)

	# Now set position (surface will register itself in its _ready())
	surface.global_position = spawn_position

	print("SpawnSurfaceEffect: Spawned %s at %s" % [surface.name, spawn_position])
