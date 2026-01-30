extends 'res://scripts/enemies/enemy_attack_behaviour.gd'
class_name MeleeAttackBehaviour

## Melee attack behavior
## Attacks when in range and cooldown allows

@export var damage: float = 10.0
@export var attack_range: float = 1.5
@export var attack_cooldown: float = 1.0  # Seconds between attacks

var time_since_last_attack: float = 0.0


func _process(delta: float):
	# Update cooldown timer
	if time_since_last_attack < attack_cooldown:
		time_since_last_attack += delta


func can_attack(enemy: Node3D, target: Node3D) -> bool:
	if not target:
		return false

	# Check cooldown
	if time_since_last_attack < attack_cooldown:
		return false

	# Check range
	var distance := enemy.global_position.distance_to(target.global_position)
	return distance <= attack_range


func execute_attack(enemy: Node3D, target: Node3D) -> void:
	# Reset cooldown
	time_since_last_attack = 0.0

	# Apply damage if target has take_damage method
	if target.has_method("take_damage"):
		target.take_damage(damage, enemy)
	else:
		push_warning("Target does not have take_damage() method")

	# TODO: Play attack animation
	# TODO: Trigger attack sound effect


func get_attack_range() -> float:
	return attack_range
