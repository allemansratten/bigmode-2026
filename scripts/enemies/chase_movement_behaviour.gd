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
		return Vector3.ZERO

	# Within attack range - stop moving
	if distance_to_target <= attack_range:
		return Vector3.ZERO

	# Update nav target to chase player
	nav_agent.target_position = target_position

	# Chase using nav agent
	if nav_agent.is_navigation_finished():
		return Vector3.ZERO

	var next_path_position := nav_agent.get_next_path_position()
	var direction := (next_path_position - enemy.global_position).normalized()

	# Rotate to face movement direction
	if direction.length() > 0.01:
		var target_transform := enemy.global_transform.looking_at(
			enemy.global_position + direction,
			Vector3.UP
		)
		enemy.global_transform = enemy.global_transform.interpolate_with(
			target_transform,
			rotation_speed * delta
		)

	return direction * move_speed
