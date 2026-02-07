class_name DashComponent
extends 'res://scripts/player/movement_component.gd'

## Dash speed in m/s (horizontal only)
@export var dash_speed: float = 15.0
## How long the dash lasts in seconds
@export var dash_duration: float = 0.16
## Number of charges (for double-dash upgrades)
@export var max_charges: int = 1
## Refill all charges when cooldown completes (vs refilling one at a time)
@export var refill_all_on_cooldown: bool = true

var _current_charges: int = 1
var _dash_direction: Vector3 = Vector3.ZERO
var _animation_controller: AnimationController = null


func _ready() -> void:
	super._ready()
	_current_charges = max_charges

	# Get AnimationController reference
	_animation_controller = _player.get_node_or_null("AnimationController")

	# Refill charges when cooldown completes
	_cooldown_timer.timeout.connect(_on_cooldown_complete)

	# Reset animation speed when dash completes
	_active_timer.timeout.connect(_on_dash_complete)


## Override: Check if dash can be activated (has charges available)
func can_activate() -> bool:
	return super.can_activate() and _current_charges > 0


## Override: Activate the dash in the given direction
func activate(current_velocity: Vector3) -> void:
	# Determine dash direction from current velocity or fallback to facing
	var horizontal := Vector3(current_velocity.x, 0.0, current_velocity.z)
	if horizontal.length_squared() > 0.01:
		_dash_direction = horizontal.normalized()
	else:
		# Fallback to player's facing direction
		_dash_direction = _player.get_facing_direction()

	# Set animation speed so dash animation completes during dash duration
	# Assuming default dash animation is ~1.8s, scale it to match dash_duration
	if _animation_controller:
		var animation_speed_multiplier = 1.8 / dash_duration  # Adjust 1.8s base to dash_duration
		_animation_controller.set_dash_animation_speed(animation_speed_multiplier)

	_activate(dash_duration)
	_current_charges -= 1

	# Start cooldown only when all charges are used
	if _current_charges == 0:
		_start_cooldown()

	performed.emit(_dash_direction)

	# Emit global event for upgrade system
	EventBus.player_dashed.emit(_dash_direction)


## Override: Apply dash velocity while active
func apply_velocity(_delta: float) -> Vector3:
	if is_active():
		return Vector3(_dash_direction.x * dash_speed, 0.0, _dash_direction.z * dash_speed)
	return Vector3.ZERO


func _on_cooldown_complete() -> void:
	if refill_all_on_cooldown:
		_current_charges = max_charges
	else:
		_current_charges = mini(_current_charges + 1, max_charges)

## Reset animation speed when dash completes
func _on_dash_complete() -> void:
	if _animation_controller:
		_animation_controller.reset_dash_animation_speed()

####
## Upgrade methods
####

func add_charge() -> void:
	max_charges += 1
	_current_charges = mini(_current_charges + 1, max_charges)


func modify_speed(multiplier: float) -> void:
	dash_speed *= multiplier


func modify_duration(multiplier: float) -> void:
	dash_duration *= multiplier
