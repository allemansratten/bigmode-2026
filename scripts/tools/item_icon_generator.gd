@tool
extends Node3D

## Tool script to generate item icons from scenes/items/
## Run this scene in the editor to generate 64x64 PNGs
##
## Usage:
## 1. Open this scene in the editor
## 2. Click "Run Current Scene" (F6) or check "Generate on Ready" and reload
## 3. Icons are saved to res://resources/icons/items/

## Generate icons when scene runs
@export var generate_on_ready: bool = true

## Output directory for icons
@export var output_dir: String = "res://resources/icons/items"

## Icon size in pixels
@export var icon_size: int = 128

## Items directory to scan
@export var items_dir: String = "res://scenes/items"

## Skip items containing these strings (e.g., projectiles)
@export var skip_patterns: Array[String] = ["Projectile"]

## Camera distance multiplier (increase if items are clipped)
@export var camera_distance_multiplier: float = 2.0

## Camera angle (rotation around Y axis in degrees)
@export var camera_angle_y: float = 35.0

## Camera pitch (rotation around X axis in degrees)
@export var camera_pitch: float = 25.0

@onready var _viewport: SubViewport = $SubViewport
@onready var _camera: Camera3D = $SubViewport/Camera3D
@onready var _item_mount: Node3D = $SubViewport/ItemMount
@onready var _key_light: DirectionalLight3D = $SubViewport/KeyLight
@onready var _fill_light: DirectionalLight3D = $SubViewport/FillLight


func _ready() -> void:
	if generate_on_ready:
		# Wait a frame for viewport to initialize
		await get_tree().process_frame
		await get_tree().process_frame
		generate_all_icons()


func generate_all_icons() -> void:
	print("ItemIconGenerator: Starting icon generation...")

	# Ensure output directory exists
	DirAccess.make_dir_recursive_absolute(output_dir)

	# Get all item scenes
	var item_scenes = _get_item_scenes()
	print("ItemIconGenerator: Found %d item scenes" % item_scenes.size())

	var generated = 0
	var skipped = 0

	for item_path in item_scenes:
		var item_name = item_path.get_file().get_basename()

		# Check skip patterns
		var should_skip = false
		for pattern in skip_patterns:
			if item_name.contains(pattern):
				should_skip = true
				break

		if should_skip:
			print("  Skipping: %s (matches skip pattern)" % item_name)
			skipped += 1
			continue

		# Generate icon
		var success = await _generate_icon(item_path)
		if success:
			generated += 1
		else:
			skipped += 1

	print("ItemIconGenerator: Complete! Generated %d icons, skipped %d" % [generated, skipped])

	# Quit if running as standalone
	if not Engine.is_editor_hint():
		get_tree().quit()


func _generate_icon(item_path: String) -> bool:
	var item_name = item_path.get_file().get_basename()
	print("  Generating: %s" % item_name)

	# Load and instance the item
	var item_scene = load(item_path) as PackedScene
	if not item_scene:
		push_warning("    Failed to load: %s" % item_path)
		return false

	var item = item_scene.instantiate()
	if not item:
		push_warning("    Failed to instantiate: %s" % item_path)
		return false

	# Disable physics for RigidBody3D items
	if item is RigidBody3D:
		item.freeze = true

	# Add to mount point
	_item_mount.add_child(item)
	item.position = Vector3.ZERO
	item.rotation = Vector3.ZERO

	# Wait for item to be in tree
	await get_tree().process_frame

	# Calculate bounding box and frame camera
	var aabb = _calculate_aabb(item)
	_frame_camera(aabb)

	# Wait for render
	await get_tree().process_frame
	await get_tree().process_frame

	# Capture viewport
	var image = _viewport.get_texture().get_image()

	# Save icon
	var output_path = output_dir.path_join(item_name + ".png")
	var error = image.save_png(output_path)

	# Cleanup
	item.queue_free()
	await get_tree().process_frame

	if error != OK:
		push_warning("    Failed to save: %s (error %d)" % [output_path, error])
		return false

	print("    Saved: %s" % output_path)
	return true


func _get_item_scenes() -> Array[String]:
	var scenes: Array[String] = []

	var dir = DirAccess.open(items_dir)
	if not dir:
		push_error("ItemIconGenerator: Cannot open items directory: %s" % items_dir)
		return scenes

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tscn"):
			scenes.append(items_dir.path_join(file_name))
		file_name = dir.get_next()

	dir.list_dir_end()
	scenes.sort()
	return scenes


func _calculate_aabb(node: Node3D) -> AABB:
	var aabb = AABB()
	var found_mesh = false

	# Find all MeshInstance3D nodes
	var meshes = _find_meshes(node)

	for mesh_instance in meshes:
		var mesh_aabb = mesh_instance.get_aabb()
		# Transform AABB to world space
		var item_global_transform = mesh_instance.global_transform

		# Get corners of local AABB and transform them
		var corners = [
			item_global_transform * Vector3(mesh_aabb.position.x, mesh_aabb.position.y, mesh_aabb.position.z),
			item_global_transform * Vector3(mesh_aabb.position.x + mesh_aabb.size.x, mesh_aabb.position.y, mesh_aabb.position.z),
			item_global_transform * Vector3(mesh_aabb.position.x, mesh_aabb.position.y + mesh_aabb.size.y, mesh_aabb.position.z),
			item_global_transform * Vector3(mesh_aabb.position.x, mesh_aabb.position.y, mesh_aabb.position.z + mesh_aabb.size.z),
			item_global_transform * Vector3(mesh_aabb.position.x + mesh_aabb.size.x, mesh_aabb.position.y + mesh_aabb.size.y, mesh_aabb.position.z),
			item_global_transform * Vector3(mesh_aabb.position.x + mesh_aabb.size.x, mesh_aabb.position.y, mesh_aabb.position.z + mesh_aabb.size.z),
			item_global_transform * Vector3(mesh_aabb.position.x, mesh_aabb.position.y + mesh_aabb.size.y, mesh_aabb.position.z + mesh_aabb.size.z),
			item_global_transform * Vector3(mesh_aabb.position.x + mesh_aabb.size.x, mesh_aabb.position.y + mesh_aabb.size.y, mesh_aabb.position.z + mesh_aabb.size.z),
		]

		for corner in corners:
			if not found_mesh:
				aabb = AABB(corner, Vector3.ZERO)
				found_mesh = true
			else:
				aabb = aabb.expand(corner)

	# Fallback if no mesh found
	if not found_mesh:
		aabb = AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1, 1, 1))

	return aabb


func _find_meshes(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []

	if node is MeshInstance3D:
		meshes.append(node)

	for child in node.get_children():
		meshes.append_array(_find_meshes(child))

	return meshes


func _frame_camera(aabb: AABB) -> void:
	var center = aabb.get_center()
	var size = aabb.size.length()

	# Calculate camera distance based on AABB size
	var distance = size * camera_distance_multiplier

	# Position camera at angle
	var angle_rad_y = deg_to_rad(camera_angle_y)
	var angle_rad_x = deg_to_rad(camera_pitch)

	var offset = Vector3(
		sin(angle_rad_y) * cos(angle_rad_x),
		sin(angle_rad_x),
		cos(angle_rad_y) * cos(angle_rad_x)
	) * distance

	_camera.position = center + offset
	_camera.look_at(center)

	# Adjust orthographic size based on AABB
	_camera.size = size * 1.2
