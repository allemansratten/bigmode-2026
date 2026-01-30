@tool
extends EditorNode3DGizmoPlugin

const PeopleSpawner = preload("res://scripts/crowd/people_spawner.gd")


func _init() -> void:
	create_material("main", Color(1.0, 0.8, 0.0, 0.8))  # Yellow/gold color
	create_material("outline", Color(1.0, 0.6, 0.0, 1.0))  # Darker orange outline
	create_handle_material("handles")


func _get_gizmo_name() -> String:
	return "PeopleSpawner"


func _has_gizmo(node: Node3D) -> bool:
	return node is PeopleSpawner


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()

	var spawner := gizmo.get_node_3d() as PeopleSpawner
	if not spawner:
		return

	var size := spawner.spawn_area_size
	var height := spawner.spawn_height

	# Create the corners of the rectangle
	var half_width := size.x / 2.0
	var half_depth := size.y / 2.0

	# Rectangle corners at spawn height
	var corners := [
		Vector3(-half_width, height, -half_depth),  # Bottom-left
		Vector3(half_width, height, -half_depth),   # Bottom-right
		Vector3(half_width, height, half_depth),    # Top-right
		Vector3(-half_width, height, half_depth),   # Top-left
	]

	# Draw the rectangle outline
	var lines := PackedVector3Array()
	for i in range(4):
		lines.append(corners[i])
		lines.append(corners[(i + 1) % 4])

	# Add vertical lines at corners to show height
	for corner in corners:
		lines.append(corner)
		lines.append(Vector3(corner.x, 0, corner.z))

	# Draw ground-level rectangle for reference
	for i in range(4):
		var ground_corner := Vector3(corners[i].x, 0, corners[i].z)
		var next_ground_corner := Vector3(corners[(i + 1) % 4].x, 0, corners[(i + 1) % 4].z)
		lines.append(ground_corner)
		lines.append(next_ground_corner)

	gizmo.add_lines(lines, get_material("outline", gizmo), false)

	# Draw a semi-transparent filled rectangle at spawn height
	var mesh := _create_area_mesh(size, height)
	gizmo.add_mesh(mesh, get_material("main", gizmo))

	# Add handles for resizing the spawn area
	var handles := PackedVector3Array()
	handles.append(Vector3(half_width, height, 0))  # Right handle (width)
	handles.append(Vector3(0, height, half_depth))  # Forward handle (depth)
	gizmo.add_handles(handles, get_material("handles", gizmo), [])


func _create_area_mesh(size: Vector2, height: float) -> ArrayMesh:
	"""Creates a semi-transparent quad mesh for the spawn area"""
	var half_width := size.x / 2.0
	var half_depth := size.y / 2.0

	var vertices := PackedVector3Array([
		Vector3(-half_width, height, -half_depth),
		Vector3(half_width, height, -half_depth),
		Vector3(half_width, height, half_depth),
		Vector3(-half_width, height, half_depth),
	])

	var indices := PackedInt32Array([
		0, 1, 2,
		0, 2, 3
	])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	return mesh


func _get_handle_name(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> String:
	match handle_id:
		0:
			return "Width"
		1:
			return "Depth"
		_:
			return ""


func _get_handle_value(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> Variant:
	var spawner := gizmo.get_node_3d() as PeopleSpawner
	if not spawner:
		return Vector2.ZERO

	return spawner.spawn_area_size


func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var spawner := gizmo.get_node_3d() as PeopleSpawner
	if not spawner:
		return

	var global_transform := spawner.global_transform
	var handle_pos := global_transform.origin

	# Get the handle's current position in world space
	match handle_id:
		0:  # Width handle
			handle_pos += global_transform.basis.x * (spawner.spawn_area_size.x / 2.0)
			handle_pos.y += spawner.spawn_height
		1:  # Depth handle
			handle_pos += global_transform.basis.z * (spawner.spawn_area_size.y / 2.0)
			handle_pos.y += spawner.spawn_height

	# Project screen position to 3D plane
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var plane := Plane(Vector3.UP, handle_pos.y)
	var intersection := plane.intersects_ray(from, dir)

	if intersection == null:
		return

	# Convert to local space
	var local_pos: Vector3 = global_transform.affine_inverse() * intersection

	# Update the appropriate dimension
	var new_size := spawner.spawn_area_size
	match handle_id:
		0:  # Width handle
			new_size.x = max(1.0, abs(local_pos.x) * 2.0)
		1:  # Depth handle
			new_size.y = max(1.0, abs(local_pos.z) * 2.0)

	spawner.spawn_area_size = new_size


func _commit_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, restore: Variant, cancel: bool) -> void:
	var spawner := gizmo.get_node_3d() as PeopleSpawner
	if not spawner:
		return

	if cancel:
		spawner.spawn_area_size = restore
		return

	# The handle has already been set via _set_handle
	# This is just for undo/redo support
	_redraw(gizmo)
