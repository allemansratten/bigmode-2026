extends Node
class_name EnemyMovementBehaviour

## Abstract base class for enemy movement strategies
## Extend this class to implement different movement behaviors (chase, patrol, flee, etc.)

# Reference to the navigation agent (set by enemy)
var nav_agent: NavigationAgent3D

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


## Optional: Called when enemy reaches destination
func on_destination_reached(_enemy: CharacterBody3D) -> void:
	pass
