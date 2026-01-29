extends Camera3D

## World position the camera looks at (e.g. floor center or player)
@export var look_target: Vector3 = Vector3.ZERO

func _ready() -> void:
	look_at(look_target)
