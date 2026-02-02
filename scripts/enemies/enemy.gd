extends CharacterBody3D
class_name Enemy

## Base enemy class
## Handles health, damage, death, and coordinates movement/attack behaviors

signal died(enemy: Enemy)
signal health_changed(current: float, maximum: float)

@export var enemy_name: String = "" # Unique identifier for this enemy type
@export var max_health: float = 100.0
@export var current_health: float = max_health
@export var gravity: float = 9.8

# Item drops
@export var drop_items: Array[PackedScene] = []
@export var drop_chance: float = 0.5 # 50% chance to drop an item

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
		nav_agent.target_desired_distance = 1.5 # Increased to prevent getting stuck near walls
		# Enable avoidance for enemy-enemy collision
		nav_agent.avoidance_enabled = true
		nav_agent.radius = 0.8 # Increased to keep paths away from walls


func _physics_process(delta: float):
	if is_dead or not target:
		return

	# Apply gravity (accumulates over frames)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# Get desired velocity from movement behavior (horizontal only)
	var target_velocity := Vector3.ZERO
	if movement_behaviour:
		target_velocity = movement_behaviour.update_movement(delta, self , target.global_position)

	# Use movement behavior's XZ but preserve accumulated Y velocity
	velocity.x = target_velocity.x
	velocity.z = target_velocity.z

	move_and_slide()

	# Check and execute attack
	if attack_behaviour and attack_behaviour.can_attack(self , target):
		attack_behaviour.execute_attack(self , target)


## Track last damage source for kill attribution
var _last_damage_source: Node3D = null

func take_damage(amount: float, source: Node3D = null) -> void:
	if is_dead:
		return

	_last_damage_source = source
	current_health -= amount
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		die()


func die() -> void:
	if is_dead:
		return

	is_dead = true
	died.emit(self)

	# Emit global event for upgrade system
	EventBus.enemy_killed.emit(self, _last_damage_source)

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


## Get the enemy type name for registry
func get_enemy_name() -> String:
	return enemy_name
