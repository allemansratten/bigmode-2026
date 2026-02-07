extends Node
class_name AnimationController

## Universal animation controller for both players and enemies
## Uses speed-based locomotion blending and handles one-shot actions
## Listens to character signals and drives AnimationTree
##
## Drop this node on any character, assign an AnimSet resource, done.
## The AnimSet defines which signals map to which actions and which
## AnimationTree states those actions correspond to — no code changes
## needed to support new characters or new action types.

## Emitted when hit frame occurs during attack animation
signal hit_frame
## Emitted for footstep sounds during locomotion
signal footstep
## Emitted when throw frame occurs during throw animation
signal throw_frame
## Emitted when attack window opens/closes for weapon systems
signal attack_window(open: bool)
## Emitted when animation events are triggered
signal animation_event(event_name: String, data: Dictionary)

## Animation configuration resource
@export var anim_set: AnimSet

## Enable debug logging for animation state changes
@export var debug_logging: bool = false

## Current animation speed multiplier for attack actions (1.0 = normal speed)
var _attack_speed_multiplier: float = 1.0
## Current animation speed multiplier for dash actions (1.0 = normal speed)
var _dash_speed_multiplier: float = 1.0
## Current animation speed multiplier for enemy attacks (1.0 = normal speed)
var _enemy_attack_speed_multiplier: float = 1.0
## Default attack animation duration (from base animation) - set when needed
var _base_attack_duration: float = 0.0

# Internal state
var _animation_tree: AnimationTree
var _state_machine: AnimationNodeStateMachinePlayback
var _character: Node3D
var _current_speed: float = 0.0
var _last_action_name: StringName = &""
var _last_action_state: StringName = &""

# Animation event tracking
var _active_attack_window: bool = false
var _hit_frame_triggered: bool = false

func _ready() -> void:
	_character = get_parent()
	if not _character:
		push_warning("AnimationController needs a parent character")
		return

	_setup_animation_tree()
	_connect_character_signals()

func _setup_animation_tree() -> void:
	if not anim_set:
		push_warning("AnimationController: No AnimSet configured")
		return

	# Use the animation tree path from AnimSet
	_animation_tree = _character.get_node_or_null(anim_set.animation_tree_path)
	if not _animation_tree:
		push_warning("AnimationController: AnimationTree not found at path: ", anim_set.animation_tree_path)
		return

	_animation_tree.active = true

	# Connect AnimationPlayer for animation events
	var anim_player_path = _animation_tree.anim_player
	var anim_player = _animation_tree.get_node_or_null(anim_player_path)
	if anim_player:
		if not anim_player.animation_finished.is_connected(_on_animation_finished):
			anim_player.animation_finished.connect(_on_animation_finished)

	if debug_logging:
		print("AnimationController: Setup complete for ", _character.name, " using AnimationTree BlendTree system")

# -- Signal connection (data-driven from AnimSet.signal_actions) -----------

func _connect_character_signals() -> void:
	if not anim_set:
		return
	for signal_name in anim_set.signal_actions:
		var action := StringName(anim_set.signal_actions[signal_name])
		_connect_action_signal(StringName(signal_name), action)

func _connect_action_signal(signal_name: StringName, action: StringName) -> void:
	if not _character.has_signal(signal_name):
		if debug_logging:
			print("AnimationController: Character missing signal: ", signal_name)
		return

	var arg_count := _get_signal_arg_count(signal_name)
	var handler := func() -> void: _handle_signal_action(action)
	if arg_count > 0:
		handler = handler.unbind(arg_count)
	if not _character.is_connected(signal_name, handler):
		_character.connect(signal_name, handler)

func _handle_signal_action(action: StringName) -> void:
	# Don't interrupt terminal actions (e.g., death)
	if anim_set.is_terminal_action(String(_last_action_name)):
		return
	request_action(action)

func _get_signal_arg_count(signal_name: StringName) -> int:
	for sig in _character.get_signal_list():
		if sig.name == signal_name:
			return sig.args.size()
	return 0

# -- Locomotion blending --------------------------------------------------

func _process(_delta: float) -> void:
	_update_locomotion_blending()

func _update_locomotion_blending() -> void:
	if not _animation_tree or not anim_set:
		return

	# Get current movement speed from character
	var speed = _get_character_speed()
	_current_speed = speed

	if anim_set.use_condition_based_locomotion:
		_update_condition_based_locomotion(speed)
	else:
		_update_blend_space_locomotion(speed)

func _update_condition_based_locomotion(speed: float) -> void:
	var is_moving = anim_set.is_moving_speed(speed)

	# Set both conditions explicitly each frame so transitions consume the correct one
	_set_condition("to_running", is_moving)
	_set_condition("to_idle", not is_moving)

	if debug_logging and not is_equal_approx(_current_speed, speed):
		print("AnimationController: Speed=", speed, " Moving=", is_moving)

func _update_blend_space_locomotion(speed: float) -> void:
	var blend_position = anim_set.get_blend_position(speed)

	# Use the locomotion blend parameter for AnimationTree
	var locomotion_param = "parameters/Locomotion/blend_position"
	if _has_parameter(locomotion_param):
		_animation_tree.set(locomotion_param, blend_position)

		if debug_logging and not is_equal_approx(_current_speed, speed):
			print("AnimationController: Speed=", speed, " Blend=", blend_position)
	elif debug_logging:
		print("AnimationController: Locomotion blend parameter not found: ", locomotion_param)

func _set_condition(condition_name: String, value: bool) -> void:
	if not _animation_tree:
		return

	var condition_path = "parameters/conditions/" + condition_name

	if not _has_parameter(condition_path):
		if debug_logging:
			print("AnimationController: Condition parameter not found: ", condition_path)
		return

	_animation_tree.set(condition_path, value)

func _get_character_speed() -> float:
	if _character.has_method("get_movement_speed"):
		return _character.get_movement_speed()

	if "velocity" in _character:
		var velocity: Vector3 = _character.velocity
		return Vector2(velocity.x, velocity.z).length()

	return 0.0

# -- One-shot action animations --------------------------------------------

## Request a one-shot action animation by action name (e.g., &"attack", &"dash")
func request_action(action: StringName) -> void:
	if not _animation_tree or not anim_set:
		if debug_logging:
			print("AnimationController: Cannot play action '", action, "' - no animation tree available")
		return

	_last_action_name = action
	_hit_frame_triggered = false
	_active_attack_window = false
	
	# Apply speed multipliers for different action types
	if action == &"attack":
		# Check if this is an enemy with attack duration set
		if _character.has_method("get_attack_duration"):
			var enemy_duration = _character.get_attack_duration()
			if enemy_duration > 0.0:
				# Scale enemy attack animation to match their attack duration
				# Assume base enemy attack animation is ~2.0s
				var enemy_speed = 2.0 / enemy_duration
				set_enemy_attack_animation_speed(enemy_speed)
				_apply_enemy_attack_speed()
			else:
				_apply_attack_speed()
		else:
			_apply_attack_speed()
		# Also apply it again after a short delay to ensure it sticks
		get_tree().create_timer(0.01).timeout.connect(func(): 
			if _character.has_method("get_attack_duration"):
				var enemy_duration = _character.get_attack_duration()
				if enemy_duration > 0.0:
					_apply_enemy_attack_speed()
				else:
					_apply_attack_speed()
			else:
				_apply_attack_speed()
		)
	elif action == &"dash":
		_apply_dash_speed()
		# Also apply it again after a short delay to ensure it sticks
		get_tree().create_timer(0.01).timeout.connect(_apply_dash_speed)
	
	# Map actions to ActionSelect transitions and OneShot triggers
	match action:
		&"attack":
			_animation_tree.set("parameters/ActionSelect/transition_request", "MeleeAttack")
			_animation_tree.set("parameters/UpperBodyOneShot/request", 1)
			if debug_logging:
				print("AnimationController: Triggered MeleeAttack via UpperBodyOneShot")
		
		&"ranged_attack":
			_animation_tree.set("parameters/ActionSelect/transition_request", "RangedAttack")
			_animation_tree.set("parameters/UpperBodyOneShot/request", 1)
			if debug_logging:
				print("AnimationController: Triggered RangedAttack via UpperBodyOneShot")
		
		&"hit":
			_animation_tree.set("parameters/ActionSelect/transition_request", "Hit")
			_animation_tree.set("parameters/UpperBodyOneShot/request", 1)
			if debug_logging:
				print("AnimationController: Triggered Hit via UpperBodyOneShot")
		
		&"throw":
			_animation_tree.set("parameters/ActionSelect/transition_request", "Throw")
			_animation_tree.set("parameters/UpperBodyOneShot/request", 1)
			if debug_logging:
				print("AnimationController: Triggered Throw via UpperBodyOneShot")
		
		&"dash":
			# Dash uses FullBodyOneShot since it affects the whole body
			_animation_tree.set("parameters/FullBodyOneShot/request", 1)
			if debug_logging:
				print("AnimationController: Triggered Dash via FullBodyOneShot")
		
		_:
			push_warning("AnimationController: No BlendTree mapping for action: ", action)

# -- Animation completion --------------------------------------------------

func _on_animation_finished(_animation_name: StringName) -> void:
	# BlendTree system: Actions auto-return to locomotion via OneShot fadeout
	_close_attack_window()
	
	# Reset speed when animation finishes
	if _animation_tree:
		var time_scale_param = "parameters/TimeScale/scale"
		if _has_parameter(time_scale_param):
			_animation_tree.set(time_scale_param, 1.0)
	
	_last_action_name = &""
	
	if debug_logging:
		print("AnimationController: Animation finished, reset to locomotion")

func _close_attack_window() -> void:
	if _active_attack_window:
		_active_attack_window = false
		attack_window.emit(false)

# -- Animation event callbacks (called via AnimationPlayer method tracks) --

func _anim_hit_frame() -> void:
	if not _hit_frame_triggered:
		_hit_frame_triggered = true
		hit_frame.emit()
		animation_event.emit("hit_frame", {"attack_state": _last_action_state})

func _anim_footstep() -> void:
	footstep.emit()
	animation_event.emit("footstep", {"speed": _current_speed})

func _anim_throw_frame() -> void:
	throw_frame.emit()
	animation_event.emit("throw_frame", {"action": _last_action_name})

func _anim_attack_window_open() -> void:
	if not _active_attack_window:
		_active_attack_window = true
		attack_window.emit(true)
		animation_event.emit("attack_window_open", {})

func _anim_attack_window_close() -> void:
	if _active_attack_window:
		_active_attack_window = false
		attack_window.emit(false)
		animation_event.emit("attack_window_close", {})

# -- Debug utilities -------------------------------------------------------

func get_current_state() -> String:
	if not _animation_tree:
		return "No AnimationTree"
	
	# For BlendTree system, check OneShot activity and ActionSelect state
	var upper_active = _animation_tree.get("parameters/UpperBodyOneShot/active")
	var full_active = _animation_tree.get("parameters/FullBodyOneShot/active")
	var action_state = _animation_tree.get("parameters/ActionSelect/current_state")
	
	if full_active:
		return "FullBodyAction"
	elif upper_active:
		return "UpperBodyAction:" + str(action_state)
	else:
		return "Locomotion"

func get_current_speed() -> float:
	return _current_speed

func get_animation_info() -> Dictionary:
	return {
		"current_state": get_current_state(),
		"current_speed": _current_speed,
		"last_action": _last_action_name,
		"hit_frame_triggered": _hit_frame_triggered,
		"attack_window_active": _active_attack_window,
		"animation_tree_active": _animation_tree.active if _animation_tree else false,
		"upper_body_oneshot_active": _animation_tree.get("parameters/UpperBodyOneShot/active") if _animation_tree else false,
		"full_body_oneshot_active": _animation_tree.get("parameters/FullBodyOneShot/active") if _animation_tree else false,
		"action_select_state": _animation_tree.get("parameters/ActionSelect/current_state") if _animation_tree else "",
		"time_scale": _animation_tree.get("parameters/TimeScale/scale") if _animation_tree else 1.0,
		"locomotion_blend": _animation_tree.get("parameters/Locomotion/blend_position") if _animation_tree else 0.0,
	}

func force_travel_to_state(state_name: StringName) -> void:
	# For BlendTree system, interpret state names as action requests
	match state_name:
		&"Attack", &"MeleeAttack":
			request_action(&"attack")
		&"RangedAttack":
			request_action(&"ranged_attack") 
		&"Hit":
			request_action(&"hit")
		&"Throw":
			request_action(&"throw")
		&"Dash":
			request_action(&"dash")
		&"Locomotion":
			# Reset to locomotion by clearing oneshots
			if _animation_tree:
				_animation_tree.set("parameters/UpperBodyOneShot/request", 0)
				_animation_tree.set("parameters/FullBodyOneShot/request", 0)
		_:
			if debug_logging:
				print("AnimationController: Unknown state for BlendTree: ", state_name)

func force_trigger_event(event_name: String) -> void:
	match event_name:
		"hit_frame":
			_anim_hit_frame()
		"throw_frame":
			_anim_throw_frame()
		"footstep":
			_anim_footstep()
		"attack_window_open":
			_anim_attack_window_open()
		"attack_window_close":
			_anim_attack_window_close()
		_:
			print("AnimationController: Unknown event: ", event_name)

## Set animation speed multiplier for attack actions
## Call this when weapon timing changes (e.g., pickup/drop)
func set_attack_animation_speed(speed_multiplier: float) -> void:
	_attack_speed_multiplier = clamp(speed_multiplier, 0.1, 10.0)
	if debug_logging:
		print("AnimationController: Attack speed multiplier set to ", _attack_speed_multiplier)

## Set animation speed multiplier for dash actions
## Call this when dash timing changes
func set_dash_animation_speed(speed_multiplier: float) -> void:
	_dash_speed_multiplier = clamp(speed_multiplier, 0.1, 10.0)
	if debug_logging:
		print("AnimationController: Dash speed multiplier set to ", _dash_speed_multiplier)

## Set animation speed multiplier for enemy attack actions
## Call this when enemy attack timing changes
func set_enemy_attack_animation_speed(speed_multiplier: float) -> void:
	_enemy_attack_speed_multiplier = clamp(speed_multiplier, 0.1, 10.0)
	if debug_logging:
		print("AnimationController: Enemy attack speed multiplier set to ", _enemy_attack_speed_multiplier)

## Reset attack animation speed to default
func reset_attack_animation_speed() -> void:
	_attack_speed_multiplier = 1.0
	_reset_time_scale()

## Reset dash animation speed to default
func reset_dash_animation_speed() -> void:
	_dash_speed_multiplier = 1.0
	_reset_time_scale()

## Reset enemy attack animation speed to default
func reset_enemy_attack_animation_speed() -> void:
	_enemy_attack_speed_multiplier = 1.0
	_reset_time_scale()

## Reset TimeScale to normal speed
func _reset_time_scale() -> void:
	if not _animation_tree:
		return
	
	# Reset TimeScale to normal speed
	var time_scale_param = "parameters/TimeScale/scale"
	if _has_parameter(time_scale_param):
		_animation_tree.set(time_scale_param, 1.0)
		if debug_logging:
			print("AnimationController: Reset TimeScale to normal speed")

## Apply the current attack speed multiplier to the animation tree
func _apply_attack_speed() -> void:
	if not _animation_tree:
		return
	
	# Use TimeScale node for perfect speed control in BlendTree system
	var time_scale_param = "parameters/TimeScale/scale"
	if _has_parameter(time_scale_param):
		_animation_tree.set(time_scale_param, _attack_speed_multiplier)
		if debug_logging:
			print("AnimationController: Applied attack speed via TimeScale: ", _attack_speed_multiplier)
	else:
		if debug_logging:
			print("AnimationController: TimeScale parameter not found!")

## Apply the current dash speed multiplier to the animation tree
func _apply_dash_speed() -> void:
	if not _animation_tree:
		return
	
	# Use TimeScale node for perfect speed control in BlendTree system
	var time_scale_param = "parameters/TimeScale/scale"
	if _has_parameter(time_scale_param):
		_animation_tree.set(time_scale_param, _dash_speed_multiplier)
		if debug_logging:
			print("AnimationController: Applied dash speed via TimeScale: ", _dash_speed_multiplier)
	else:
		if debug_logging:
			print("AnimationController: TimeScale parameter not found!")

## Apply the current enemy attack speed multiplier to the animation tree
func _apply_enemy_attack_speed() -> void:
	if not _animation_tree:
		return
	
	# Use TimeScale node for perfect speed control in BlendTree system
	var time_scale_param = "parameters/TimeScale/scale"
	if _has_parameter(time_scale_param):
		_animation_tree.set(time_scale_param, _enemy_attack_speed_multiplier)
		if debug_logging:
			print("AnimationController: Applied enemy attack speed via TimeScale: ", _enemy_attack_speed_multiplier)
	else:
		if debug_logging:
			print("AnimationController: TimeScale parameter not found!")

# -- Helpers ---------------------------------------------------------------

func _has_parameter(param_path: String) -> bool:
	if not _animation_tree:
		return false
	var value = _animation_tree.get(param_path)
	return value != null
