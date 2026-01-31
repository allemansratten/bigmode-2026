extends Area3D
class_name Projectile

## Projectile that flies in a direction and deals damage on collision

@export var damage: float = 10.0
@export var speed: float = 15.0
@export var lifetime: float = 5.0  # Self-destruct after this many seconds
@export var pierce: bool = false  # Can hit multiple targets

var direction: Vector3 = Vector3.FORWARD
var source: Node3D = null  # Who fired this projectile
var hit_targets: Array[Node3D] = []  # Track what we've already hit

var _lifetime_timer: Timer


func _ready():
	# Set up lifetime timer
	_lifetime_timer = Timer.new()
	_lifetime_timer.wait_time = lifetime
	_lifetime_timer.one_shot = true
	_lifetime_timer.timeout.connect(_on_lifetime_timeout)
	add_child(_lifetime_timer)
	_lifetime_timer.start()

	# Connect collision signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float):
	# Move forward
	global_position += direction * speed * delta


## Initialize projectile with direction and source
func initialize(fire_direction: Vector3, fire_source: Node3D, fire_damage: float = 10.0):
	direction = fire_direction.normalized()
	source = fire_source
	damage = fire_damage

	# Orient projectile to face direction
	if direction.length() > 0.01:
		look_at(global_position + direction, Vector3.UP)


func _on_body_entered(body: Node3D):
	_handle_collision(body)


func _on_area_entered(area: Node3D):
	# Check if area's parent is a valid target
	if area.get_parent():
		_handle_collision(area.get_parent())


func _handle_collision(target: Node3D):
	# Don't hit the source
	if target == source:
		return

	# Don't hit the same target twice
	if target in hit_targets:
		return

	hit_targets.append(target)

	# Apply damage if target can take it
	if target.has_method("take_damage"):
		target.take_damage(damage, source)
		print("Projectile hit %s for %s damage" % [target.name, damage])

	# Destroy projectile (unless piercing)
	if not pierce:
		queue_free()


func _on_lifetime_timeout():
	queue_free()
