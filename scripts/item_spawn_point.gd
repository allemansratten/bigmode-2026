extends Marker3D
class_name ItemSpawnPoint

## Marker for where items spawn from (at room edges)
## Items are thrown from this point towards ItemThrowTarget nodes

## Optional: Specific spawn direction override (if not throwing towards target)
@export var spawn_direction: Vector3 = Vector3.ZERO

## Optional: Visual indicator color
@export var gizmo_color: Color = Color.CYAN


func _ready() -> void:
	# Hide in game (only visible in editor)
	visible = false
