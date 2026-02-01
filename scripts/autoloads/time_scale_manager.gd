extends Node

## TimeScaleManager - Global singleton for managing game speed / bullet time effects
##
## Usage:
## ```gdscript
## # Request slowdown with auto-cancel
## TimeScaleManager.request_time_scale(0.5, 2.0)  # 0.5x speed for 2 seconds
##
## # Request slowdown with manual cancel
## var bullet_time_id = TimeScaleManager.request_time_scale(0.1)  # 0.1x speed until canceled
## TimeScaleManager.cancel_time_scale(bullet_time_id)
## ```
##
## Multiple effects can be active simultaneously. The slowest speed always wins.

## Signal emitted when time scale changes
signal time_scale_changed(new_scale: float)

## Currently active time scale effects
var _active_effects: Dictionary = {}  # {id: {time_scale: float, timer: Timer}}

## Current effective time scale (computed from active effects)
var _current_time_scale: float = 1.0

## Counter for generating unique IDs
var _id_counter: int = 0

## Tween for smooth transitions
var _tween: Tween

## Default transition time for smooth interpolation
const DEFAULT_TRANSITION_TIME: float = 0.2


func _ready() -> void:
	# Register debug commands
	DebugConsole.register_command("timescale", "Set time scale (e.g., timescale 0.5)")
	DebugConsole.register_command("timescale_clear", "Clear all time scale effects")
	DebugConsole.command_entered.connect(_on_debug_command)


## Request a time scale effect
## @param time_scale: Target speed (0.01 to 1.0, where 1.0 is normal speed)
## @param duration: Seconds until auto-cancel. Use -1 or 0 for manual cancel
## @param transition_time: Smooth interpolation duration in seconds
## @returns: Unique ID string for manual cancellation
func request_time_scale(
	time_scale: float,
	duration: float = -1.0,
	transition_time: float = DEFAULT_TRANSITION_TIME
) -> String:
	# Clamp time_scale to valid range
	# Minimum 0.01 prevents true freeze (which breaks tweens/timers)
	time_scale = clampf(time_scale, 0.01, 1.0)

	# Generate unique ID
	var id = _generate_id()

	# Create effect data
	var effect_data = {
		"time_scale": time_scale,
		"timer": null
	}

	# Setup auto-cancel timer if duration is specified
	if duration > 0.0:
		var timer = Timer.new()
		timer.one_shot = true
		timer.wait_time = duration
		timer.timeout.connect(func(): _auto_cancel_effect(id))
		add_child(timer)
		timer.start()
		effect_data.timer = timer

	# Store effect
	_active_effects[id] = effect_data

	# Recalculate and apply new time scale
	_update_time_scale(transition_time)

	return id


## Cancel a specific time scale effect by ID
## @param id: The unique ID returned from request_time_scale
## @param transition_time: Smooth interpolation duration in seconds
func cancel_time_scale(id: String, transition_time: float = DEFAULT_TRANSITION_TIME) -> void:
	if not _active_effects.has(id):
		return

	# Clean up timer if it exists
	var effect_data = _active_effects[id]
	if effect_data.timer != null:
		effect_data.timer.queue_free()

	# Remove effect
	_active_effects.erase(id)

	# Recalculate and apply new time scale
	_update_time_scale(transition_time)


## Clear all active time scale effects and return to normal speed
## Uses a small transition to prevent physics/rendering errors
func clear_all_effects() -> void:
	# Clean up all timers
	for effect_data in _active_effects.values():
		if effect_data.timer != null:
			effect_data.timer.queue_free()

	# Clear all effects
	_active_effects.clear()

	# Use small transition to prevent NaN/Infinity in physics calculations
	# Instant transitions from very slow speeds cause rendering errors
	_apply_time_scale(1.0, 0.05)


## Get the current effective time scale (readonly)
func get_current_time_scale() -> float:
	return _current_time_scale


## Generate a unique ID for an effect
func _generate_id() -> String:
	_id_counter += 1
	return "ts_%d_%d" % [Time.get_ticks_msec(), _id_counter]


## Auto-cancel callback for timed effects
func _auto_cancel_effect(id: String) -> void:
	cancel_time_scale(id)


## Recalculate effective time scale from all active effects and apply it
func _update_time_scale(transition_time: float) -> void:
	var new_time_scale = _calculate_minimum_time_scale()
	_apply_time_scale(new_time_scale, transition_time)


## Calculate the minimum (slowest) time scale from all active effects
func _calculate_minimum_time_scale() -> float:
	if _active_effects.is_empty():
		return 1.0

	var min_scale = 1.0
	for effect_data in _active_effects.values():
		min_scale = min(min_scale, effect_data.time_scale)

	return min_scale


## Apply the time scale with smooth transition
func _apply_time_scale(target_scale: float, transition_time: float) -> void:
	# Cancel existing tween if any
	if _tween and _tween.is_valid():
		_tween.kill()

	# If no transition time, apply immediately
	if transition_time <= 0.0:
		_set_engine_time_scale(target_scale)
		return

	# Create smooth transition
	_tween = create_tween()
	_tween.tween_method(_set_engine_time_scale, _current_time_scale, target_scale, transition_time)

	print("TimeScaleManager: applying time scale: ", target_scale)
	print("TimeScaleManager: all active effects: ", _active_effects)


## Internal method to set engine time scale and emit signal
func _set_engine_time_scale(scale: float) -> void:
	var old_scale = _current_time_scale
	_current_time_scale = scale
	Engine.time_scale = scale

	# Only emit if scale actually changed
	if not is_equal_approx(old_scale, scale):
		time_scale_changed.emit(scale)


## Handle debug console commands
func _on_debug_command(cmd: String, args: PackedStringArray) -> void:
	match cmd:
		"timescale":
			if args.size() > 0:
				var scale = float(args[0])
				clear_all_effects()
				# Use small transition to prevent rendering errors
				request_time_scale(scale, -1, 0.05)
				DebugConsole.debug_log("Time scale set to: " + str(scale))
			else:
				DebugConsole.debug_log("Usage: timescale <value>")
		"timescale_clear":
			clear_all_effects()
			DebugConsole.debug_log("All time scale effects cleared")
