extends 'res://scripts/surfaces/surface.gd'
class_name OilSurface

## Oil surface - slows entity movement
## Persistent until cleaned by water

func _ready() -> void:
	surface_type = SurfaceEffect.Type.OIL

	# Set defaults if not configured
	if radius == 2.0:  # Default value, hasn't been changed
		radius = 2.0
	if lifetime == 0.0:
		lifetime = 0.0  # Persistent

	super._ready()


func _create_surface_material() -> Material:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.1, 0.05, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.3
	mat.roughness = 0.7
	return mat
