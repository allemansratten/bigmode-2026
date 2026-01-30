extends CharacterBody3D
class_name Enemy

## Base enemy class
## Handles health, damage, death, and coordinates movement/attack behaviors

signal died(enemy: Enemy)
signal health_changed(current: float, maximum: float)

@export var max_health: float = 100.0
@export var current_health: float = max_health

# Item drops
@export var drop_items: Array[PackedScene] = []
@export var drop_chance: float = 0.5  # 50% chance to drop an item

# Behavior references (assigned via get_node or added as children)
var movement_behaviour: EnemyMovementBehaviour
var attack_behaviour: EnemyAttackBehaviour

# Navigation
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

# Target (player)
var target: Node3D = null

# State
var is_dead: bool = false


func _ready():
	# Find behaviors in children
	for child in get_children():
		if child is EnemyMovementBehaviour:
			movement_behaviour = child
		elif child is EnemyAttackBehaviour:
			attack_behaviour = child

	# Pass attack range to movement behavior if both exist
	if movement_behaviour and attack_behaviour:
		if movement_behaviour is ChaseMovementBehaviour:
			movement_behaviour.attack_range = attack_behaviour.get_attack_range()

	# Find player
	target = get_tree().get_first_node_in_group("player")

	if not target:
		push_warning("Enemy could not find player in 'player' group")

	# Ensure health is set
	current_health = max_health

	# Wait for nav mesh to be ready
	call_deferred("_setup_navigation")


func _setup_navigation():
	if nav_agent:
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = 0.5
		# Enable avoidance for enemy-enemy collision
		nav_agent.avoidance_enabled = true
		nav_agent.radius = 0.5


func _physics_process(delta: float):
	if is_dead or not target:
		return

	# Update navigation target
	if nav_agent and target:
		nav_agent.target_position = target.global_position

	# Get desired velocity from movement behavior
	var target_velocity := Vector3.ZERO
	if movement_behaviour:
		target_velocity = movement_behaviour.update_movement(delta, self, target.global_position)

	# Apply velocity
	velocity = target_velocity
	move_and_slide()

	# Check and execute attack
	if attack_behaviour and attack_behaviour.can_attack(self, target):
		attack_behaviour.execute_attack(self, target)


func take_damage(amount: float, _source: Node3D = null) -> void:
	if is_dead:
		return

	current_health -= amount
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		die()


func die() -> void:
	if is_dead:
		return

	is_dead = true
	died.emit(self)

	# Spawn item drops
	if drop_items.size() > 0 and randf() < drop_chance:
		var drop_scene = drop_items.pick_random()
		if drop_scene:
			var drop_instance = drop_scene.instantiate()
			get_parent().add_child(drop_instance)
			drop_instance.global_position = global_position + Vector3.UP * 0.5

	# Remove enemy
	queue_free()


func get_distance_to_target() -> float:
	if target:
		return global_position.distance_to(target.global_position)
	return INF
