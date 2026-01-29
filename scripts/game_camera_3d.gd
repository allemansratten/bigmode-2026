extends Camera3D

## World-space offset from the parent (e.g. player). Camera moves with parent but keeps fixed rotation.
@export var offset: Vector3 = Vector3(8.0, 10.0, 8.0)

var _fixed_rotation: Vector3

func _ready() -> void:
	var parent_3d := get_parent() as Node3D
	if parent_3d:
		global_position = parent_3d.global_position + offset
		look_at(parent_3d.global_position)
	_fixed_rotation = global_rotation


func _process(_delta: float) -> void:
	var parent_3d := get_parent() as Node3D
	if parent_3d:
		global_position = parent_3d.global_position + offset
		global_rotation = _fixed_rotation
