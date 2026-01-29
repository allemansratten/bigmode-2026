extends CharacterBody3D

## Move speed in m/s
@export var move_speed: float = 5.0
## Downward acceleration when in the air
@export var gravity: float = 9.8

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Get input (WASD via move_* actions in Project Settings -> Input Map)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	# Movement relative to camera: W = up on screen, S = down, A/D = left/right
	var direction := Vector3.ZERO
	var cam := get_viewport().get_camera_3d()
	if cam:
		var cam_basis := cam.global_transform.basis
		# Screen "up" = from camera toward look-at, flattened to XZ
		var forward_screen := Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z)
		forward_screen = forward_screen.normalized()
		# Screen "right" = camera right, flattened to XZ
		var right_screen := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z)
		right_screen = right_screen.normalized()
		direction = (-input_dir.y * forward_screen + input_dir.x * right_screen)
		if direction.length_squared() > 0.0:
			direction = direction.normalized()
	else:
		# Fallback: world-relative (e.g. no camera)
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	move_and_slide()
