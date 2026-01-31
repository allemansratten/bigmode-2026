extends 'res://scripts/surfaces/surface.gd'
class_name IceSurface

## Ice surface - increases entity movement speed
## Timed duration (melts after 30 seconds)
## TODO: Add sliding momentum (reduced direction control)

func _ready() -> void:
	surface_type = SurfaceEffect.Type.ICE

	# Set defaults if not configured
	if radius == 2.0:  # Default value
		radius = 2.5  # Slightly larger than oil
	if lifetime == 0.0:
		lifetime = 30.0  # Melts after 30 seconds

	super._ready()


func _create_surface_material() -> Material:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.85, 1.0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.5
	mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.9, 1.0, 1)
	mat.emission_energy_multiplier = 0.2
	return mat
