extends CharacterBody3D
class_name Enemy

## Base enemy class
## Handles health, damage, death, and coordinates movement/attack behaviors

signal died(enemy: Enemy)
signal health_changed(current: float, maximum: float)
signal started_moving()
signal stopped_moving()
signal started_attacking()
signal took_damage(amount: float)
signal started_dying()

@export var enemy_name: String = "" # Unique identifier for this enemy type
@export var max_health: float = 100.0
@export var current_health: float = max_health
@export var gravity: float = 9.8

# Item drops
@export var drop_items: Array[PackedScene] = []
@export var drop_chance: float = 0.5 # 50% chance to drop an item

# Crowd excitement
@export var threat_level: float = 10.0 ## Excitement added to crowd when killed

# Behavior references (assigned via get_node or added as children)
var movement_behaviour: EnemyMovementBehaviour
var attack_behaviour: EnemyAttackBehaviour

# Navigation
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

# Target (player)
var target: Node3D = null

# State
var is_dead: bool = false
var is_attacking: bool = false
var is_stunned: bool = false

# Movement signal tracking
var _was_moving: bool = false

# Timers
var _attack_timer: Timer
var _stun_timer: Timer


func _ready():
	# Find behaviors in children
	for child in get_children():
		if child is EnemyMovementBehaviour:
			movement_behaviour = child
		elif child is EnemyAttackBehaviour:
			attack_behaviour = child

	# Pass attack range to movement behavior if both exist
	if movement_behaviour and attack_behaviour:
		movement_behaviour.set_attack_range(attack_behaviour.get_attack_range())

	# Find player
	target = get_tree().get_first_node_in_group("player")

	if not target:
		push_warning("Enemy could not find player in 'player' group")

	# Ensure health is set
	current_health = max_health

	# Setup timers
	_attack_timer = Timer.new()
	_attack_timer.one_shot = true
	_attack_timer.timeout.connect(_on_attack_finished)
	add_child(_attack_timer)
	
	_stun_timer = Timer.new()
	_stun_timer.one_shot = true
	_stun_timer.timeout.connect(_on_stun_finished)
	add_child(_stun_timer)

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
	if movement_behaviour and not is_attacking and not is_stunned:
		target_velocity = movement_behaviour.update_movement(delta, self , target.global_position)

	# Emit movement signals on state change (works for all movement behaviors)
	var is_moving := target_velocity.length() > 0.01
	if is_moving and not _was_moving:
		started_moving.emit()
	elif not is_moving and _was_moving:
		stopped_moving.emit()
	_was_moving = is_moving

	# Use movement behavior's XZ but preserve accumulated Y velocity
	velocity.x = target_velocity.x
	velocity.z = target_velocity.z

	move_and_slide()

	# Check and execute attack (only if not stunned or already attacking)
	if attack_behaviour and not is_attacking and not is_stunned and attack_behaviour.can_attack(self , target):
		attack_behaviour.execute_attack(self , target)


## Track last damage source for kill attribution
var _last_damage_source: Node3D = null

func take_damage(amount: float, source: Node3D = null) -> void:
	if is_dead:
		return

	_last_damage_source = source
	current_health -= amount
	health_changed.emit(current_health, max_health)

	# Always emit damage signal for other systems
	took_damage.emit(amount)

	# Check if enemy will die
	if current_health <= 0:
		# Die immediately but without hit stun to go straight to death animation
		die()
	else:
		# Apply normal hit stun for non-fatal damage
		is_stunned = true
		_stun_timer.start(0.4)


func die() -> void:
	if is_dead:
		return

	is_dead = true

	# Emit death signal for animations
	started_dying.emit()
	
	died.emit(self)

	# Emit global event for upgrade system
	EventBus.enemy_killed.emit(self, _last_damage_source)

	# Increase crowd excitement based on threat level
	var crowd_manager = get_tree().get_first_node_in_group("crowd_manager")
	if crowd_manager and crowd_manager.has_method("increase_excitement"):
		crowd_manager.increase_excitement(threat_level)

	# Spawn item drops
	if drop_items.size() > 0 and randf() < drop_chance:
		var drop_scene = drop_items.pick_random()
		if drop_scene:
			var drop_instance = drop_scene.instantiate()
			get_parent().add_child(drop_instance)
			drop_instance.global_position = global_position + Vector3.UP * 0.5

	# Remove enemy after death animation (2 seconds)
	get_tree().create_timer(2.0).timeout.connect(queue_free)


func get_distance_to_target() -> float:
	if target:
		return global_position.distance_to(target.global_position)
	return INF


## Get the enemy type name for registry
func get_enemy_name() -> String:
	return enemy_name


## Signal helpers for behaviors to use
func signal_start_attacking() -> void:
	is_attacking = true
	started_attacking.emit()


## Set attack duration (called by attack behaviors)
func set_attack_duration(duration: float) -> void:
	_attack_timer.start(duration)


## Timer callbacks
func _on_attack_finished() -> void:
	is_attacking = false


func _on_stun_finished() -> void:
	is_stunned = false
