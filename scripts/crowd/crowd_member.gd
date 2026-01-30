extends Node3D
class_name CrowdMember

## Individual crowd member NPC
## Represents a single person in the crowd with basic visual representation
## Bounces based on CrowdManager's excitement level

## Optional: Animation state for future use
@export var animation_state: String = "idle"

## Optional: Variation seed for randomizing appearance
@export var variation_seed: int = 0

## Base Y position (before bouncing)
var base_height: float = 0.0

## Random speed multiplier for variation
var bounce_speed_multiplier: float = 1.0

## Random phase offset for wave effect
var bounce_phase: float = 0.0

## Current target bounce parameters (updated via signal)
var target_bounce_height: float = 0.0
var target_bounce_speed: float = 0.0


func _ready() -> void:
	# Store initial height
	base_height = position.y

	# Randomize variations
	bounce_speed_multiplier = randf_range(0.9, 1.1)
	bounce_phase = randf() * TAU

	# Find and connect to CrowdManager
	var crowd_manager := _find_crowd_manager()
	if crowd_manager:
		crowd_manager.excitement_changed.connect(_on_excitement_changed)

	# Apply visual variations based on seed
	if variation_seed > 0:
		_apply_variation()


func _process(delta: float) -> void:
	# Animate bouncing based on current target parameters
	if target_bounce_height > 0.0:
		# Calculate time for jump cycle with phase offset and speed variation
		var time := Time.get_ticks_msec() / 1000.0
		var cycle_time := time * target_bounce_speed * bounce_speed_multiplier + bounce_phase

		# Normalize to 0-1 range for one jump cycle
		var t := fmod(cycle_time, TAU) / TAU

		# Apply jump curve with proper easing
		var jump_height: float
		if t < 0.5:
			# Rising phase (0 to 0.5) - ease out quad
			var rise_t := t * 2.0  # Map to 0-1
			jump_height = _ease_out_quad(rise_t)
		else:
			# Falling phase (0.5 to 1) - ease in quad
			var fall_t := (t - 0.5) * 2.0  # Map to 0-1
			jump_height = 1.0 - _ease_in_quad(fall_t)

		# Apply height and update position
		position.y = base_height + jump_height * target_bounce_height
	else:
		# Return to base height when not excited
		position.y = lerp(position.y, base_height, delta * 2.0)


func _on_excitement_changed(excitement: float) -> void:
	"""Called when CrowdManager's excitement level changes"""
	if excitement > 0.0:
		# Calculate bounce parameters based on excitement
		var bounce_intensity := excitement / 100.0  # Normalize to 0-1

		# Different bounce behaviors based on excitement ranges
		if excitement < 20.0:
			# Subtle sway
			target_bounce_height = 0.3
			target_bounce_speed = 1.0
		elif excitement < 50.0:
			# Light bouncing
			target_bounce_height = 0.5
			target_bounce_speed = 1.5
		elif excitement < 80.0:
			# Active bouncing
			target_bounce_height = 0.8
			target_bounce_speed = 2.5
		else:
			# Energetic jumping
			target_bounce_height = 1.2
			target_bounce_speed = 3.5

		# Scale height slightly by intensity for smooth transitions
		target_bounce_height *= (0.5 + bounce_intensity * 0.5)
	else:
		# Reset bounce parameters
		target_bounce_height = 0.0
		target_bounce_speed = 0.0


func _ease_out_quad(t: float) -> float:
	"""Ease out quadratic - decelerates at the end"""
	return 1.0 - (1.0 - t) * (1.0 - t)


func _ease_in_quad(t: float) -> float:
	"""Ease in quadratic - accelerates at the start"""
	return t * t


func _find_crowd_manager() -> CrowdManager:
	"""Traverses up the parent chain to find the CrowdManager"""
	var current := get_parent()
	while current:
		if current is CrowdManager:
			return current
		current = current.get_parent()

	push_warning("CrowdMember: Could not find CrowdManager in parent chain")
	return null


func _apply_variation() -> void:
	"""Apply random variations to appearance based on seed"""
	# TODO: Randomize colors, scale, rotation slightly
	pass
