extends EnemyAttackBehaviour
class_name RangedAttackBehaviour

## Ranged attack behavior
## Attacks target from a distance by spawning projectiles

@export var damage: float = 8.0
@export var attack_range: float = 10.0
@export var attack_cooldown: float = 2.0  # Seconds between attacks
@export var attack_duration: float = 1.5  # How long the attack animation lasts
@export var projectile_speed: float = 15.0
@export var projectile_scene: PackedScene = preload("res://scenes/items/Projectile.tscn")
@export var attack_sound: AudioStream  # Sound to play when attack starts
@export var attack_sound_delay: float = 0.0  # Delay before playing attack sound

var _cooldown_timer: Timer
var _fallback_projectile_timer: Timer  # Fallback timer to spawn projectile if animation event fails
var _animation_controller: AnimationController
var _current_target: Node3D  # Store target for delayed projectile spawn


func _ready() -> void:
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = true
	add_child(_cooldown_timer)
	
	# Connect to parent enemy's animation controller hit_frame signal
	call_deferred("_connect_animation_controller")


func can_attack(enemy: Node3D, target: Node3D) -> bool:
	if not target:
		return false

	# Only attack when standing still (not repositioning or retreating)
	if "is_moving" in enemy and enemy.is_moving:
		return false

	# Check cooldown
	if not _cooldown_timer.is_stopped():
		return false

	# Check range
	var distance := enemy.global_position.distance_to(target.global_position)
	if distance > attack_range:
		return false

	# Check line of sight (basic version - no obstacles check yet)
	return _has_line_of_sight(enemy, target)


func execute_attack(enemy: Node3D, target: Node3D) -> void:
	# Start cooldown timer
	_cooldown_timer.start(attack_cooldown)

	# Make enemy face the target when attacking
	_face_target(enemy, target)

	# Signal attack start for animation and set attack duration
	if enemy.has_method("signal_start_attacking"):
		enemy.signal_start_attacking()
	
	if enemy.has_method("set_attack_duration"):
		enemy.set_attack_duration(attack_duration)

	# Store target for delayed projectile spawn on hit frame
	_current_target = target
	print("RangedAttackBehaviour: Attack initiated against ", target.name)

	# Play attack sound
	if attack_sound:
		if attack_sound_delay > 0.0:
			get_tree().create_timer(attack_sound_delay).timeout.connect(func(): Audio.play_sound(attack_sound, Audio.Channels.SFX))
		else:
			Audio.play_sound(attack_sound, Audio.Channels.SFX)
			
	# Start fallback timer to spawn projectile if animation event fails
	if not _fallback_projectile_timer:
		_setup_fallback_timer()
	_fallback_projectile_timer.start(attack_duration * 0.5)  # Spawn at 50% of attack duration


func get_attack_range() -> float:
	return attack_range


## Basic line of sight check
func _has_line_of_sight(enemy: Node3D, target: Node3D) -> bool:
	var space_state := enemy.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		enemy.global_position + Vector3.UP * 0.8,  # Eye level
		target.global_position + Vector3.UP * 0.8
	)
	# Ignore enemy collision layer
	query.collision_mask = 1 | 2  # Environment and player

	var result := space_state.intersect_ray(query)

	# If we hit something, check if it's the target
	if result.is_empty():
		return true

	var hit_collider = result.get("collider")
	return hit_collider == target

func _connect_animation_controller() -> void:
	# Find AnimationController in parent enemy
	var enemy = get_parent()
	if enemy:
		_animation_controller = enemy.get_node_or_null("AnimationController")
		if _animation_controller:
			_animation_controller.hit_frame.connect(_on_hit_frame)
			print("RangedAttackBehaviour: Connected to AnimationController hit_frame signal")
		else:
			push_warning("RangedAttackBehaviour: No AnimationController found on enemy")
	print("RangedAttackBehaviour: Animation controller setup completed")


func _setup_fallback_timer() -> void:
	_fallback_projectile_timer = Timer.new()
	_fallback_projectile_timer.one_shot = true
	_fallback_projectile_timer.timeout.connect(_on_fallback_projectile)
	add_child(_fallback_projectile_timer)


func _on_fallback_projectile() -> void:
	print("RangedAttackBehaviour: Fallback timer triggering projectile spawn")
	_spawn_projectile()


func _on_hit_frame() -> void:
	# Spawn projectile when hit frame occurs during attack animation
	print("RangedAttackBehaviour: Hit frame received from animation")
	_spawn_projectile()


func _spawn_projectile() -> void:
	if not _current_target or not is_instance_valid(_current_target):
		print("RangedAttackBehaviour: No valid target for projectile spawn")
		return
	
	var enemy = get_parent()
	if not enemy:
		print("RangedAttackBehaviour: No enemy parent found")
		return
	
	if not projectile_scene:
		push_warning("No projectile scene set for ranged attack")
		return

	var projectile := projectile_scene.instantiate() as Projectile
	if not projectile:
		push_error("Projectile scene did not instantiate as Projectile")
		return

	# Add to scene at enemy position (slightly above center)
	var spawn_position: Vector3 = enemy.global_position + Vector3.UP * 0.8
	enemy.get_parent().add_child(projectile)
	projectile.global_position = spawn_position

	# Calculate direction to target
	var direction: Vector3 = (_current_target.global_position + Vector3.UP * 0.8 - spawn_position).normalized()

	# Initialize projectile
	projectile.initialize(direction, enemy, damage)
	projectile.speed = projectile_speed
	
	print("RangedAttackBehaviour: Projectile spawned against ", _current_target.name)
	
	# Stop fallback timer and clear target to prevent double spawn
	if _fallback_projectile_timer:
		_fallback_projectile_timer.stop()
	_current_target = null


## Make enemy face the target when attacking
func _face_target(enemy: Node3D, target: Node3D) -> void:
	if not enemy or not target:
		return
		
	# Calculate direction from enemy to target (only on horizontal plane)
	var enemy_pos = enemy.global_position
	var target_pos = target.global_position
	
	# Use only X and Z coordinates for horizontal rotation
	var direction = Vector3(target_pos.x - enemy_pos.x, 0, target_pos.z - enemy_pos.z).normalized()
	
	if direction.length() > 0.01:  # Avoid rotation with zero vector
		# Calculate the rotation to face the target
		var target_rotation = atan2(direction.x, direction.z)
		# Add 180° rotation to compensate for model being rotated in scene
		enemy.rotation.y = target_rotation + PI