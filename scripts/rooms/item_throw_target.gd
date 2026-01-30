extends Marker3D
class_name ItemThrowTarget

## Marker for where items should be thrown towards
## Placed manually in rooms; spawning manager picks random target

## Optional: Target weight (higher = more likely to be chosen)
@export var weight: float = 1.0

## Optional: Visual indicator color
@export var gizmo_color: Color = Color.YELLOW


func _ready() -> void:
	# Hide in game (only visible in editor)
	visible = false
