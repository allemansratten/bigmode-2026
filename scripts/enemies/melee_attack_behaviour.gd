extends 'res://scripts/enemies/enemy_attack_behaviour.gd'
class_name MeleeAttackBehaviour

## Melee attack behavior
## Attacks when in range and cooldown allows

@export var damage: float = 10.0
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 3.0  # Longer cooldown to ensure animation completes
@export var attack_duration: float = 2.0  # How long the attack animation lasts
@export var show_range_indicator: bool = false  # Show visual range indicator
@export var attack_arc_degrees: float = 180.0  # Attack arc in degrees
@export var attack_sound: AudioStream  # Sound to play when attack starts
@export var attack_sound_delay: float = 0.0  # Delay before playing attack sound

var _cooldown_timer: Timer
var _current_target: Node3D  # Store target for delayed damage
var _range_indicator: MeshInstance3D  # Visual range indicator
var _animation_controller: AnimationController
var _fallback_damage_timer: Timer  # Fallback for when animation events don't work


func _ready() -> void:
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = true
	add_child(_cooldown_timer)
	
	# Fallback damage timer in case animation events don't work
	_fallback_damage_timer = Timer.new()
	_fallback_damage_timer.one_shot = true
	_fallback_damage_timer.timeout.connect(_on_fallback_damage)
	add_child(_fallback_damage_timer)
	
	if show_range_indicator:
		_create_range_indicator()
	
	# Connect to parent enemy's animation controller hit_frame signal
	call_deferred("_connect_animation_controller")


func _create_range_indicator() -> void:
	# Create an arc mesh to show attack range and angle
	_range_indicator = MeshInstance3D.new()
	var array_mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	# Create arc geometry
	var segments = 32
	var half_arc = deg_to_rad(attack_arc_degrees * 0.5)
	
	# Center vertex
	vertices.append(Vector3.ZERO)
	uvs.append(Vector2(0.5, 0.5))
	
	# Arc vertices
	for i in range(segments + 1):
		var angle = -half_arc + (half_arc * 2.0 * i / segments)
		var x = sin(angle) * attack_range
		var z = cos(angle) * attack_range
		vertices.append(Vector3(x, 0, z))
		uvs.append(Vector2(0.5 + x / attack_range * 0.5, 0.5 + z / attack_range * 0.5))
		
		# Create triangles (skip the last segment)
		if i < segments:
			indices.append(0)
			indices.append(i + 1)
			indices.append(i + 2)
	
	# Create the mesh
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_range_indicator.mesh = array_mesh
	
	# Create a simple material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.RED
	material.albedo_color.a = 0.3  # Semi-transparent
	material.flags_transparent = true
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Show from both sides
	_range_indicator.material_override = material
	
	# Add to parent enemy
	var enemy = get_parent()
	if enemy:
		enemy.call_deferred("add_child", _range_indicator)
		_range_indicator.position = Vector3(0, 0.01, 0)  # Slightly above ground
		# Rotate indicator 180° to match the rotated model's facing direction
		_range_indicator.rotation_degrees.y = 180.0
		_range_indicator.visible = false  # Hidden by default


func can_attack(enemy: Node3D, target: Node3D) -> bool:
	if not target:
		return false

	# Check if enemy is still in attacking state
	if "is_attacking" in enemy and enemy.is_attacking:
		return false

	# Check cooldown
	if not _cooldown_timer.is_stopped():
		return false

	# Check if target is in attack arc
	var in_range = _is_target_in_attack_arc(enemy, target)
	
	# Range indicator is managed during attack execution, not here
	
	return in_range


func _is_target_in_attack_arc(enemy: Node3D, target: Node3D) -> bool:
	var distance: float = enemy.global_position.distance_to(target.global_position)
	if distance > attack_range:
		return false
	
	# Get enemy forward direction (original direction since model rotation affects visuals, not logic)
	var enemy_forward = -enemy.global_transform.basis.z
	var to_target = (target.global_position - enemy.global_position).normalized()
	
	# Calculate angle between forward direction and target
	var angle_to_target = enemy_forward.angle_to(to_target)
	var half_arc = deg_to_rad(attack_arc_degrees * 0.5)
	
	return angle_to_target <= half_arc


func execute_attack(enemy: Node3D, target: Node3D) -> void:
	# Show range indicator during attack to warn player of danger zone
	if _range_indicator and show_range_indicator:
		_range_indicator.visible = true

	# Start cooldown timer
	_cooldown_timer.start(attack_cooldown)

	# Store target for delayed damage
	_current_target = target
	print("MeleeAttackBehaviour: Stored target for damage: ", target.name)

	# Signal attack start for animation and set attack duration
	if enemy.has_method("signal_start_attacking"):
		enemy.signal_start_attacking()
		print("MeleeAttackBehaviour: Signaled attack start")
	
	if enemy.has_method("set_attack_duration"):
		enemy.set_attack_duration(attack_duration)
		print("MeleeAttackBehaviour: Set attack duration: ", attack_duration)

	# Start fallback damage timer (50% through attack animation)
	_fallback_damage_timer.start(attack_duration * 0.5)
	print("MeleeAttackBehaviour: Started fallback damage timer for: ", attack_duration * 0.5, " seconds")

	# Play attack sound
	if attack_sound:
		if attack_sound_delay > 0.0:
			get_tree().create_timer(attack_sound_delay).timeout.connect(func(): Audio.play_sound(attack_sound, Audio.Channels.SFX))
		else:
			Audio.play_sound(attack_sound, Audio.Channels.SFX)


func _deal_damage() -> void:
	# Hide range indicator when damage is dealt
	if _range_indicator:
		_range_indicator.visible = false
	
	print("MeleeAttackBehaviour: _deal_damage() called")
	
	# Check if target is still valid and in attack arc when damage should be dealt
	if not _current_target or not is_instance_valid(_current_target):
		print("MeleeAttackBehaviour: No valid target for damage")
		return
		
	var enemy = get_parent()
	if not enemy:
		print("MeleeAttackBehaviour: No enemy parent found")
		return
		
	print("MeleeAttackBehaviour: Target valid: ", _current_target.name, " Enemy: ", enemy.name)
	
	# Verify target is still in attack arc when damage is dealt
	if not _is_target_in_attack_arc(enemy, _current_target):
		print("MeleeAttackBehaviour: Target escaped attack arc")
		return  # Target escaped, no damage
	
	print("MeleeAttackBehaviour: Applying ", damage, " damage to ", _current_target.name)
	
	# Apply damage
	if _current_target.has_method("take_damage"):
		_current_target.take_damage(damage, enemy)
		print("MeleeAttackBehaviour: Damage applied successfully")
	else:
		print("MeleeAttackBehaviour: Target does not have take_damage() method")
	
	# Stop fallback timer and clear target to prevent double damage
	_fallback_damage_timer.stop()
	_current_target = null  # Clear reference


func _connect_animation_controller() -> void:
	# Find AnimationController in parent enemy
	var enemy = get_parent()
	if enemy:
		_animation_controller = enemy.get_node_or_null("AnimationController")
		if _animation_controller:
			_animation_controller.hit_frame.connect(_on_hit_frame)
			print("MeleeAttackBehaviour: Connected to AnimationController hit_frame signal")
		else:
			push_warning("MeleeAttackBehaviour: No AnimationController found on enemy")


func _on_hit_frame() -> void:
	# Deal damage when hit frame occurs during attack animation
	print("MeleeAttackBehaviour: Hit frame received, dealing damage")
	# Cancel fallback timer since we got the proper hit frame
	_fallback_damage_timer.stop()
	_deal_damage()


func _on_fallback_damage() -> void:
	# Fallback damage trigger in case animation events don't work
	print("MeleeAttackBehaviour: Fallback damage timer triggered")
	_deal_damage()


func get_attack_range() -> float:
	return attack_range
