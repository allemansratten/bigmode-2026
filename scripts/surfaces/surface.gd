extends Node3D
class_name Surface

## Base class for environmental surfaces (oil, ice, water)
## Surfaces affect entity movement when standing on them
## Multiple surfaces can stack - only the top one (highest Y) has effect

signal lifetime_expired(surface: Surface)

@export var surface_type: SurfaceEffect.Type = SurfaceEffect.Type.OIL
@export var effect: SurfaceEffect
@export var radius: float = 2.0  # Surface coverage radius (XZ plane)
@export var lifetime: float = 0.0  # 0 = persistent, >0 = timed in seconds

var _lifetime_timer: Timer = null

const PUDDLE_SCENE = preload("res://resources/models/Puddles/puddles.fbx")


func _ready() -> void:
	# Setup random puddle mesh
	_setup_random_puddle_mesh()
	# Auto-create effect if not assigned
	if not effect:
		effect = _create_default_effect()

	# Setup lifetime timer if needed
	if lifetime > 0.0:
		_lifetime_timer = Timer.new()
		_lifetime_timer.one_shot = true
		_lifetime_timer.timeout.connect(_on_lifetime_expired)
		add_child(_lifetime_timer)
		_lifetime_timer.start(lifetime)

	# Register with room
	_register_with_room()


func _create_default_effect() -> SurfaceEffect:
	var new_effect = SurfaceEffect.new()
	new_effect.surface_type = surface_type

	# Default multipliers based on type
	match surface_type:
		SurfaceEffect.Type.OIL:
			new_effect.movement_speed_multiplier = 0.5
		SurfaceEffect.Type.ICE:
			new_effect.movement_speed_multiplier = 1.2
		SurfaceEffect.Type.WATER:
			new_effect.movement_speed_multiplier = 1.0

	return new_effect


func _register_with_room() -> void:
	# Find parent room and register this surface
	var room = get_tree().get_first_node_in_group("room")
	if room and room.has_method("add_surface"):
		room.add_surface(self)
	else:
		push_warning("Surface %s could not find Room to register with" % name)


func _on_lifetime_expired() -> void:
	lifetime_expired.emit(self)

	# Unregister from room
	var room = get_tree().get_first_node_in_group("room")
	if room and room.has_method("remove_surface"):
		room.remove_surface(self)

	queue_free()


## Check if a position is within this surface's radius (XZ plane only)
func overlaps_position(pos: Vector3, check_radius: float = 0.0) -> bool:
	var surface_xz = Vector2(global_position.x, global_position.z)
	var pos_xz = Vector2(pos.x, pos.z)
	var distance = surface_xz.distance_to(pos_xz)
	return distance <= (radius + check_radius)


## Get all other surfaces that overlap with this one
func get_overlapping_surfaces() -> Array[Surface]:
	var room = get_tree().get_first_node_in_group("room")
	if not room or not room.has_method("get_surfaces_in_radius"):
		return []

	var overlapping: Array[Surface] = []
	var all_surfaces = room.get_surfaces_in_radius(global_position, radius)

	for surface in all_surfaces:
		if surface != self:
			overlapping.append(surface)

	return overlapping


## Setup a random puddle mesh from the puddles model
func _setup_random_puddle_mesh() -> void:
	# Find or create MeshInstance3D child
	var mesh_instance: MeshInstance3D = null
	for child in get_children():
		if child is MeshInstance3D:
			mesh_instance = child
			break

	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		add_child(mesh_instance)

	# Load puddles scene and pick random mesh
	var puddles_scene = PUDDLE_SCENE.instantiate()
	var mesh_nodes: Array[MeshInstance3D] = []

	# Collect all MeshInstance3D nodes from puddles
	_collect_mesh_instances(puddles_scene, mesh_nodes)

	if mesh_nodes.size() > 0:
		# Pick random mesh
		var random_idx = randi() % mesh_nodes.size()
		var random_mesh_node = mesh_nodes[random_idx]

		# Copy mesh
		mesh_instance.mesh = random_mesh_node.mesh

		# Fix orientation (puddles are upside down, rotate 270° on X axis)
		mesh_instance.rotation_degrees.x = 270

		# Calculate scale based on mesh size to match radius
		if mesh_instance.mesh:
			var aabb = mesh_instance.mesh.get_aabb()
			# After 270° X rotation, Y becomes the "up" axis, so use X and Z for diameter
			var mesh_diameter = max(aabb.size.x, aabb.size.z)

			if mesh_diameter > 0.0:
				# Target diameter = radius * 2 (radius is half the puddle width)
				var target_diameter = radius * 2.0
				var target_scale = target_diameter / mesh_diameter
				print("Surface: Mesh diameter: %.3f, target: %.3f, scale: %.3f" % [mesh_diameter, target_diameter, target_scale])

				# Animate scale from 0 to target (spilling effect)
				mesh_instance.scale = Vector3.ZERO
				var tween = create_tween()
				tween.set_ease(Tween.EASE_OUT)
				tween.set_trans(Tween.TRANS_BACK)
				tween.tween_property(mesh_instance, "scale", Vector3(target_scale, target_scale, target_scale), 0.4)
			else:
				# Fallback if mesh size is invalid
				mesh_instance.scale = Vector3(100, 100, 100)

		# Apply surface-specific material
		var material = _create_surface_material()
		if material:
			mesh_instance.material_override = material

	# Clean up temporary scene
	puddles_scene.queue_free()


## Recursively collect all MeshInstance3D nodes
func _collect_mesh_instances(node: Node, array: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		array.append(node)

	for child in node.get_children():
		_collect_mesh_instances(child, array)


## Create material for this surface type - override in subclasses
func _create_surface_material() -> Material:
	return null
