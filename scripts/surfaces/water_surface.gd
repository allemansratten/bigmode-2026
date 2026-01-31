extends 'res://scripts/surfaces/surface.gd'
class_name WaterSurface

## Water surface - neutral movement effect
## Cleans/removes other surfaces (oil, ice) when spawned
## Timed duration (evaporates after 20 seconds)

func _ready() -> void:
	surface_type = SurfaceEffect.Type.WATER

	# Set defaults if not configured
	if radius == 2.0:  # Default value
		radius = 2.0
	if lifetime == 0.0:
		lifetime = 20.0  # Evaporates after 20 seconds

	super._ready()

	# Clean overlapping surfaces after registering with room
	call_deferred("_clean_overlapping_surfaces")


func _create_surface_material() -> Material:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.4, 0.8, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.6
	mat.roughness = 0.2
	return mat


func _clean_overlapping_surfaces() -> void:
	var overlapping = get_overlapping_surfaces()

	for surface in overlapping:
		# Water cleans oil and ice
		if surface.surface_type == SurfaceEffect.Type.OIL or surface.surface_type == SurfaceEffect.Type.ICE:
			print("Water surface %s cleaning %s" % [name, surface.name])

			# Remove from room and destroy
			var room = get_tree().get_first_node_in_group("room")
			if room and room.has_method("remove_surface"):
				room.remove_surface(surface)

			surface.queue_free()
