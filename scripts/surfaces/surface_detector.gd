extends Node
class_name SurfaceDetector

## Component that detects which surface an entity is standing on
## Attached to Player or Enemy to apply surface effects

signal surface_changed(old_surface: Surface, new_surface: Surface)

@export var detection_interval: float = 0.1  # Check every 0.1 seconds
@export var debug_print: bool = false

var entity: Node3D
var current_surface: Surface = null

var _detection_timer: Timer


func _ready() -> void:
	entity = get_parent() as Node3D

	if not entity:
		push_error("SurfaceDetector must be child of a Node3D entity")
		return

	# Setup detection timer
	_detection_timer = Timer.new()
	_detection_timer.wait_time = detection_interval
	_detection_timer.timeout.connect(_detect_surface)
	add_child(_detection_timer)
	_detection_timer.start()


func _detect_surface() -> void:
	var room = get_tree().get_first_node_in_group("room")
	if not room or not room.has_method("get_top_surface_at_position"):
		return

	# Query room for surface at entity's center position
	var surface = room.get_top_surface_at_position(entity.global_position)

	# Surface changed?
	if surface != current_surface:
		var old_surface = current_surface
		current_surface = surface
		surface_changed.emit(old_surface, current_surface)

		if debug_print:
			if current_surface:
				print("%s: Now on surface %s (type: %s)" % [
					entity.name,
					current_surface.name,
					SurfaceEffect.Type.keys()[current_surface.surface_type]
				])
			else:
				print("%s: Left surface" % entity.name)


## Get the current surface's effect, or null if not on any surface
func get_current_effect() -> SurfaceEffect:
	if current_surface:
		return current_surface.effect
	return null


## Get the movement speed multiplier from current surface (1.0 if no surface)
func get_speed_multiplier() -> float:
	if current_surface and current_surface.effect:
		return current_surface.effect.movement_speed_multiplier
	return 1.0
