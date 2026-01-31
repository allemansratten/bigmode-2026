extends Resource
class_name SurfaceEffect

## Data container for surface behavior effects
## Defines how a surface affects entities standing on it

enum Type {
	OIL,    # Sticky/slow movement
	ICE,    # Fast/slippery movement
	WATER   # Neutral, cleans other surfaces
}

@export var surface_type: Type = Type.OIL
@export var movement_speed_multiplier: float = 1.0
@export var friction_modifier: float = 1.0  # For future use (sliding, etc.)

## Optional visual/audio feedback
@export var entry_particle_scene: PackedScene = null
@export var entry_sound: AudioStream = null
