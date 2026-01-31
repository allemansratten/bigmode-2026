extends Node
class_name EnemyAttackBehaviour

## Abstract base class for enemy attack strategies
## Extend this class to implement different attack behaviors (melee, ranged, AoE, etc.)

## Override this method to check if attack is possible
## Returns true if the enemy can attack the target right now
func can_attack(_enemy: Node3D, _target: Node3D) -> bool:
	push_error("can_attack() must be implemented in derived class")
	return false


## Override this method to execute the attack
## Called when can_attack() returns true and cooldown allows
func execute_attack(_enemy: Node3D, _target: Node3D) -> void:
	push_error("execute_attack() must be implemented in derived class")


## Override this method to return the attack range
## Used to determine when to stop moving toward target
func get_attack_range() -> float:
	push_error("get_attack_range() must be implemented in derived class")
	return 0.0
