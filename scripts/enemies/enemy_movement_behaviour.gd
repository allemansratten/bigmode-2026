extends Node
class_name EnemyMovementBehaviour

## Abstract base class for enemy movement strategies
## Extend this class to implement different movement behaviors (chase, patrol, flee, etc.)
##
## Contract: update_movement() is only called when the enemy can move
## (not dead, not attacking, not stunned). Don't re-check those states.

# Reference to the navigation agent (set by enemy)
var nav_agent: NavigationAgent3D

@export var rotation_speed: float = 8.0


func _ready():
	# Find NavigationAgent3D in parent
	var parent = get_parent()
	if parent:
		nav_agent = parent.get_node_or_null("NavigationAgent3D")


## Override this method in derived classes to implement movement logic
## Returns the velocity to apply to the enemy
func update_movement(_delta: float, _enemy: CharacterBody3D, _target_position: Vector3) -> Vector3:
	push_error("update_movement() must be implemented in derived class")
	return Vector3.ZERO


## Called by Enemy to pass the attack range from the attack behavior.
## Override in subclasses that need to know the stopping distance.
func set_attack_range(_range: float) -> void:
	pass


## Rotate enemy to face movement direction with interpolation
func apply_rotation(delta: float, enemy: CharacterBody3D, direction: Vector3) -> void:
	if direction.length() <= 0.01:
		return
	var up_dot = abs(direction.dot(Vector3.UP))
	if up_dot >= 0.99:
		return
	var target_transform := enemy.global_transform.looking_at(
		enemy.global_position + direction,
		Vector3.UP
	)
	enemy.global_transform = enemy.global_transform.interpolate_with(
		target_transform,
		rotation_speed * delta
	)


## Apply surface speed multiplier to base movement speed
func get_effective_speed(enemy: CharacterBody3D, base_speed: float) -> float:
	var surface_detector = enemy.get_node_or_null("SurfaceDetector") as SurfaceDetector
	if surface_detector:
		return base_speed * surface_detector.get_speed_multiplier()
	return base_speed


## Optional: Called when enemy reaches destination
func on_destination_reached(_enemy: CharacterBody3D) -> void:
	pass
