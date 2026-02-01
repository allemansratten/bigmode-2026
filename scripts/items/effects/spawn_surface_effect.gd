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

	# Raycast downward from impact position to find floor
	var impact_position = item.global_position
	var floor_position = _find_floor_position(impact_position)

	# Use floor position with offset, or fallback to impact position if no floor found
	var spawn_position = floor_position + spawn_offset

	# Instance and spawn the surface
	var surface = surface_scene.instantiate()

	# Add to room first (surface needs to be in tree before setting global_position)
	room.add_child(surface)

	# Now set position (surface will register itself in its _ready())
	surface.global_position = spawn_position

	print("SpawnSurfaceEffect: Spawned %s at %s" % [surface.name, spawn_position])


## Raycast downward to find floor position
func _find_floor_position(from_position: Vector3) -> Vector3:
	var space_state = item.get_world_3d().direct_space_state

	# Raycast downward from impact position (max 10 units down)
	var ray_origin = from_position
	var ray_end = from_position + Vector3(0, -10, 0)

	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = CollisionLayers.get_mask(CollisionLayers.Layer.ENVIRONMENT)

	var result = space_state.intersect_ray(query)

	if result:
		# Found floor, return hit position
		return result.position
	else:
		# No floor found, return original position (flask may have hit the floor directly)
		return from_position
