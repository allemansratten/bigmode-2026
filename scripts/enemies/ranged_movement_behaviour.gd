extends EnemyMovementBehaviour
class_name RangedMovementBehaviour

## Ranged unit movement - maintains distance from target with hysteresis
## Uses state machine to prevent jittering at boundary distances

enum State {
	IDLE,           # In attack range, holding position
	APPROACHING,    # Moving toward player
	RETREATING,     # Moving away from player
	REPOSITIONING   # Finding escape route when cornered
}

# Distance thresholds (with hysteresis to prevent oscillation)
@export var max_distance: float = 12.0       # Further than this: start approaching
@export var approach_distance: float = 10.0  # When approaching: stop at this distance
@export var min_distance: float = 4.0        # Closer than this: start retreating
@export var retreat_distance: float = 7.0    # When retreating: stop at this distance

@export var move_speed: float = 3.0
@export var rotation_speed: float = 8.0

# Repositioning when cornered
@export var reposition_check_distance: float = 2.0  # How far ahead to check for obstacles
@export var reposition_search_radius: float = 10.0  # Radius to search for safe positions

var current_state: State = State.IDLE
var current_target_position: Vector3 = Vector3.ZERO


func update_movement(delta: float, enemy: CharacterBody3D, target_position: Vector3) -> Vector3:
	if not nav_agent:
		return Vector3.ZERO

	var distance_to_target := enemy.global_position.distance_to(target_position)

	# Update state based on distance and current state
	_update_state(distance_to_target)

	# Execute behavior based on current state
	var desired_position := _get_desired_position(enemy, target_position, distance_to_target)

	# If idle (in attack range), don't move
	if current_state == State.IDLE:
		return Vector3.ZERO

	# Update navigation target
	current_target_position = desired_position
	nav_agent.target_position = desired_position

	# Get velocity from nav agent
	if nav_agent.is_navigation_finished():
		# Reached target - always transition to idle
		current_state = State.IDLE
		return Vector3.ZERO

	# Fallback: if we're very close to target, consider it reached
	# (handles cases where is_navigation_finished doesn't trigger)
	if enemy.global_position.distance_to(current_target_position) < nav_agent.target_desired_distance:
		current_state = State.IDLE
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


## Update state machine based on distance to target
func _update_state(distance_to_target: float) -> void:
	match current_state:
		State.IDLE:
			# Check if we need to start moving
			if distance_to_target > max_distance:
				current_state = State.APPROACHING
			elif distance_to_target < min_distance:
				current_state = State.RETREATING

		State.APPROACHING:
			# Stop approaching when we reach approach_distance
			if distance_to_target <= approach_distance:
				current_state = State.IDLE

		State.RETREATING:
			# Stop retreating when we reach retreat_distance
			if distance_to_target >= retreat_distance:
				current_state = State.IDLE

		State.REPOSITIONING:
			# Stay in repositioning until navigation finishes
			# Transitions to IDLE when target reached in update_movement
			pass


## Get the desired position based on current state
func _get_desired_position(enemy: CharacterBody3D, target_position: Vector3, distance_to_target: float) -> Vector3:
	match current_state:
		State.APPROACHING:
			return target_position

		State.RETREATING:
			# Try to retreat away from player
			var retreat_direction := (enemy.global_position - target_position).normalized()
			var retreat_dist := retreat_distance - distance_to_target + 1.0  # Retreat to safe distance
			var retreat_target := enemy.global_position + retreat_direction * retreat_dist

			# Check if we can retreat in this direction
			if _can_retreat_to(enemy, retreat_target):
				return retreat_target
			else:
				# Cornered! Switch to repositioning
				current_state = State.REPOSITIONING
				return _find_reposition_point(enemy, target_position)

		State.REPOSITIONING:
			# Continue to current reposition target
			return current_target_position

		State.IDLE, _:
			return enemy.global_position


## Check if we can retreat to a position without hitting obstacles
func _can_retreat_to(_enemy: CharacterBody3D, retreat_pos: Vector3) -> bool:
	# Use NavigationServer to check if path exists and is reasonable
	var nav_map := nav_agent.get_navigation_map()
	var closest_point := NavigationServer3D.map_get_closest_point(nav_map, retreat_pos)

	# Check if the closest valid point is close to where we want to go
	var distance_to_valid := retreat_pos.distance_to(closest_point)

	# If the valid point is far from our desired retreat position, we're probably blocked
	return distance_to_valid < reposition_check_distance


## Find a safe position to reposition to when cornered
func _find_reposition_point(enemy: CharacterBody3D, threat_position: Vector3) -> Vector3:
	var nav_map := nav_agent.get_navigation_map()
	var best_position := enemy.global_position
	var best_score := -INF

	# Sample points in a circle around the enemy
	var sample_count := 16
	for i in range(sample_count):
		var angle := (TAU / sample_count) * i
		var offset := Vector3(
			cos(angle) * reposition_search_radius,
			0,
			sin(angle) * reposition_search_radius
		)
		var sample_pos := enemy.global_position + offset

		# Get closest valid point on nav mesh
		var valid_pos := NavigationServer3D.map_get_closest_point(nav_map, sample_pos)

		# Skip if not reachable
		if valid_pos.distance_to(sample_pos) > reposition_check_distance:
			continue

		# Score based on distance from threat (higher is better)
		var distance_from_threat := valid_pos.distance_to(threat_position)

		# Prefer positions that are farther from the threat
		var score := distance_from_threat

		if score > best_score:
			best_score = score
			best_position = valid_pos

	return best_position
