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

var _cooldown_timer: Timer
var _damage_timer: Timer
var _current_target: Node3D  # Store target for delayed damage
var _range_indicator: MeshInstance3D  # Visual range indicator


func _ready() -> void:
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = true
	add_child(_cooldown_timer)
	
	_damage_timer = Timer.new()
	_damage_timer.one_shot = true
	_damage_timer.timeout.connect(_deal_damage)
	add_child(_damage_timer)
	
	if show_range_indicator:
		_create_range_indicator()


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

	# Signal attack start for animation and set attack duration
	if enemy.has_method("signal_start_attacking"):
		enemy.signal_start_attacking()
	
	if enemy.has_method("set_attack_duration"):
		enemy.set_attack_duration(attack_duration)

	# Deal damage at the end of attack animation (50% through to feel impactful)
	_damage_timer.start(attack_duration * 0.5)

	# TODO: Play attack animation
	# TODO: Trigger attack sound effect


func _deal_damage() -> void:
	# Hide range indicator when damage is dealt
	if _range_indicator:
		_range_indicator.visible = false
		
	# Check if target is still valid and in attack arc when damage should be dealt
	if not _current_target or not is_instance_valid(_current_target):
		return
		
	var enemy = get_parent()
	if not enemy:
		return
		
	# Verify target is still in attack arc when damage is dealt
	if not _is_target_in_attack_arc(enemy, _current_target):
		return  # Target escaped, no damage
	
	# Apply damage
	if _current_target.has_method("take_damage"):
		_current_target.take_damage(damage, enemy)
	else:
		push_warning("Target does not have take_damage() method")
	
	_current_target = null  # Clear reference


func get_attack_range() -> float:
	return attack_range
