class_name MovementComponent
extends Node

## Emitted when this movement ability is performed (emitted by subclasses)
@warning_ignore("unused_signal")
signal performed(direction: Vector3)

## Cooldown duration in seconds
@export var cooldown: float = 1.0
## Whether this ability can be used
@export var enabled: bool = true

var _cooldown_timer: Timer
var _active_timer: Timer
var _player: CharacterBody3D


func _ready() -> void:
	_player = get_parent() as CharacterBody3D
	_setup_timers()


func _setup_timers() -> void:
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = true
	add_child(_cooldown_timer)

	_active_timer = Timer.new()
	_active_timer.one_shot = true
	add_child(_active_timer)


## Override in subclasses - return true if ability should activate
func can_activate() -> bool:
	return enabled and _cooldown_timer.is_stopped()


## Override in subclasses - perform the movement
func activate(_current_velocity: Vector3) -> void:
	push_error("MovementComponent.activate() not implemented in " + get_script().resource_path)


## Call after activation to start cooldown
func _start_cooldown() -> void:
	_cooldown_timer.start(cooldown)


## Call after activation to start active duration
func _activate(duration: float) -> void:
	_active_timer.start(duration)


## Override in subclasses if you need custom active state tracking
func is_active() -> bool:
	return !_active_timer.is_stopped()


## Override in subclasses - return velocity to apply while active
func apply_velocity(_delta: float) -> Vector3:
	return Vector3.ZERO


## For upgrades to modify cooldown (multiplier, e.g. 0.8 = 20% faster)
func modify_cooldown(multiplier: float) -> void:
	cooldown *= multiplier
