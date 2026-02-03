extends EnemyMovementBehaviour
class_name ChaseMovementBehaviour

## Chases the target using NavigationAgent3D
## Stops when within attack range, idles when too far away

@export var move_speed: float = 3
@export var max_chase_distance: float = 50.0  # Stop chasing if target is beyond this distance
@export var rotation_speed: float = 10.0  # How fast enemy rotates to face target

var attack_range: float = 0.0  # Set by enemy based on attack behavior


func update_movement(delta: float, enemy: CharacterBody3D, target_position: Vector3) -> Vector3:
	if not nav_agent:
		return Vector3.ZERO

	var distance_to_target := enemy.global_position.distance_to(target_position)

	# Too far away - idle
	if distance_to_target > max_chase_distance:
		# Signal stop moving for idle animation
		if enemy.has_method("signal_stop_moving"):
			enemy.signal_stop_moving()
		return Vector3.ZERO

	# Check if enemy is attacking or stunned - stop moving
	if "is_attacking" in enemy and enemy.is_attacking:
		if enemy.has_method("signal_stop_moving"):
			enemy.signal_stop_moving()
		return Vector3.ZERO
		
	if "is_stunned" in enemy and enemy.is_stunned:
		if enemy.has_method("signal_stop_moving"):
			enemy.signal_stop_moving()
		return Vector3.ZERO

	# Within attack range - stop moving
	if distance_to_target <= attack_range:
		# Signal stop moving when in attack range
		if enemy.has_method("signal_stop_moving"):
			enemy.signal_stop_moving()
		return Vector3.ZERO

	# Update nav target to chase player
	nav_agent.target_position = target_position

	# Chase using nav agent
	if nav_agent.is_navigation_finished():
		# Signal stop moving when reached destination
		if enemy.has_method("signal_stop_moving"):
			enemy.signal_stop_moving()
		return Vector3.ZERO

	# Signal start moving when chasing
	if enemy.has_method("signal_start_moving"):
		enemy.signal_start_moving()

	var next_path_position := nav_agent.get_next_path_position()
	var direction := (next_path_position - enemy.global_position).normalized()

	# Rotate to face movement direction
	if direction.length() > 0.01:
		# Check if direction is nearly vertical to avoid colinear warning
		var up_dot = abs(direction.dot(Vector3.UP))
		if up_dot < 0.99:  # Not pointing straight up/down
			var target_transform := enemy.global_transform.looking_at(
				enemy.global_position + direction,
				Vector3.UP
			)
			enemy.global_transform = enemy.global_transform.interpolate_with(
				target_transform,
				rotation_speed * delta
			)

	# Apply surface effect to movement speed
	var effective_speed = move_speed
	var surface_detector = enemy.get_node_or_null("SurfaceDetector") as SurfaceDetector
	if surface_detector:
		effective_speed *= surface_detector.get_speed_multiplier()

	return direction * effective_speed
