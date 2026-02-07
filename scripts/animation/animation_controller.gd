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

# Mode detection
var _use_state_machine: bool = false

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

	# Try the configured path first (if not empty)
	if anim_set.animation_tree_path != NodePath(""):
		_animation_tree = _character.get_node_or_null(anim_set.animation_tree_path)
		if debug_logging and not _animation_tree:
			print("AnimationController: Configured path failed, searching for AnimationTree...")
	
	# If that fails or path is empty, search for AnimationTree in character hierarchy
	if not _animation_tree:
		_animation_tree = _find_animation_tree(_character)
		if debug_logging and _animation_tree:
			print("AnimationController: Found AnimationTree via search at: ", _character.get_path_to(_animation_tree))
	
	if not _animation_tree:
		if anim_set.animation_tree_path != NodePath(""):
			push_warning("AnimationController: AnimationTree not found at configured path: ", anim_set.animation_tree_path)
		push_warning("AnimationController: No AnimationTree found in character hierarchy")
		return

	_animation_tree.active = true

	# Debug: Print available parameters
	if debug_logging:
		print("AnimationController: Available parameters:")
		var test_params = [
			"parameters/BlendSpace1D/blend_position",
			"parameters/OneShot/request", 
			"parameters/OneShot/active",
			"parameters/Transition/transition_request",
			"parameters/Transition/current_state",
			"parameters/TimeScale/scale"
		]
		for param in test_params:
			if _has_parameter(param):
				var value = _animation_tree.get(param)
				print("  ", param, " = ", value)

	# Detect which mode to use based on AnimSet configuration
	_use_state_machine = anim_set.use_condition_based_locomotion and anim_set.state_machine_path != ""
	
	if _use_state_machine:
		# Set up state machine playback for enemies
		_state_machine = _animation_tree.get(anim_set.state_machine_path)
		if not _state_machine:
			push_warning("AnimationController: StateMachine not found at path: ", anim_set.state_machine_path)
			_use_state_machine = false
		else:
			if debug_logging:
				print("AnimationController: Using StateMachine mode for ", _character.name)

	# Connect AnimationPlayer for animation events
	var anim_player_path = _animation_tree.anim_player
	var anim_player = _animation_tree.get_node_or_null(anim_player_path)
	if anim_player:
		if not anim_player.animation_finished.is_connected(_on_animation_finished):
			anim_player.animation_finished.connect(_on_animation_finished)

	if debug_logging:
		var mode_str = "BlendTree" if not _use_state_machine else "StateMachine"
		print("AnimationController: Setup complete for ", _character.name, " using ", mode_str, " system")

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

	# Use the locomotion blend parameter for AnimationTree - try both naming conventions
	var locomotion_param = "parameters/Locomotion/blend_position"
	if not _has_parameter(locomotion_param):
		locomotion_param = "parameters/BlendSpace1D/blend_position"
	
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
	
	if _use_state_machine:
		_handle_state_machine_action(action)
	else:
		_handle_blend_tree_action(action)

func _handle_state_machine_action(action: StringName) -> void:
	if not _state_machine:
		push_warning("AnimationController: No StateMachine available for action: ", action)
		return
		
	var state_name = anim_set.get_state_for_action(String(action))
	if state_name == "":
		if debug_logging:
			print("AnimationController: No state mapping for action: ", action)
		return
	
	_last_action_state = StringName(state_name)
	
	# Apply speed multipliers for state machine mode
	_apply_action_speed_multipliers(action)
	
	# Travel to the target state
	_state_machine.travel(state_name)
	
	if debug_logging:
		print("AnimationController: StateMachine traveled to state: ", state_name, " for action: ", action)

func _handle_blend_tree_action(action: StringName) -> void:
	# Apply speed multipliers for different action types
	_apply_action_speed_multipliers(action)
	
	# Map actions to ActionSelect transitions and OneShot triggers
	# Try both naming conventions for parameter paths
	var action_select_param = "parameters/ActionSelect/transition_request"
	var oneshot_param = "parameters/UpperBodyOneShot/request"
	var fullbody_oneshot_param = "parameters/FullBodyOneShot/request"
	
	# Check for alternative naming conventions used in fish dwarf model
	if not _has_parameter(action_select_param):
		action_select_param = "parameters/Transition/transition_request"
	if not _has_parameter(oneshot_param):
		oneshot_param = "parameters/OneShot/request"
	
	match action:
		&"attack":
			if _has_parameter(action_select_param):
				_animation_tree.set(action_select_param, "Attack")
			if _has_parameter(oneshot_param):
				_animation_tree.set(oneshot_param, 1)
			if debug_logging:
				print("AnimationController: Triggered Attack via OneShot")
		
		&"ranged_attack":
			if _has_parameter(action_select_param):
				_animation_tree.set(action_select_param, "RangedAttack")
			if _has_parameter(oneshot_param):
				_animation_tree.set(oneshot_param, 1)
			if debug_logging:
				print("AnimationController: Triggered RangedAttack via OneShot")
		
		&"hit":
			if _has_parameter(action_select_param):
				_animation_tree.set(action_select_param, "Hit")
			if _has_parameter(oneshot_param):
				_animation_tree.set(oneshot_param, 1)
			if debug_logging:
				print("AnimationController: Triggered Hit via OneShot")
		
		&"throw":
			if _has_parameter(action_select_param):
				_animation_tree.set(action_select_param, "Throw")
			if _has_parameter(oneshot_param):
				_animation_tree.set(oneshot_param, 1)
			if debug_logging:
				print("AnimationController: Triggered Throw via OneShot")
		
		&"dash":
			# Dash uses FullBodyOneShot since it affects the whole body
			if _has_parameter(fullbody_oneshot_param):
				_animation_tree.set(fullbody_oneshot_param, 1)
			if debug_logging:
				print("AnimationController: Triggered Dash via FullBodyOneShot")
		
		&"death":
			if _has_parameter(action_select_param):
				_animation_tree.set(action_select_param, "Death")
			if _has_parameter(oneshot_param):
				_animation_tree.set(oneshot_param, 1)
			if debug_logging:
				print("AnimationController: Triggered Death via OneShot")
		
		_:
			push_warning("AnimationController: No BlendTree mapping for action: ", action)

func _apply_action_speed_multipliers(action: StringName) -> void:
	match action:
		&"attack":
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
		&"dash":
			_apply_dash_speed()
			# Also apply it again after a short delay to ensure it sticks
			get_tree().create_timer(0.01).timeout.connect(_apply_dash_speed)

# -- Animation completion --------------------------------------------------

func _on_animation_finished(_animation_name: StringName) -> void:
	if _use_state_machine:
		_handle_state_machine_finished()
	else:
		_handle_blend_tree_finished()

func _handle_state_machine_finished() -> void:
	# StateMachine: Return to locomotion unless it's a terminal action
	if not anim_set.is_terminal_action(String(_last_action_name)) and _state_machine:
		_state_machine.travel(anim_set.state_locomotion)
		if debug_logging:
			print("AnimationController: StateMachine returned to locomotion state: ", anim_set.state_locomotion)
	
	_close_attack_window()
	_reset_time_scale()
	_last_action_name = &""
	_last_action_state = &""

func _handle_blend_tree_finished() -> void:
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
	print("AnimationController: _anim_hit_frame() called")
	if not _hit_frame_triggered:
		_hit_frame_triggered = true
		hit_frame.emit()
		print("AnimationController: hit_frame signal emitted")
		animation_event.emit("hit_frame", {"attack_state": _last_action_state})
	else:
		print("AnimationController: hit_frame already triggered for this animation")

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
	
	if _use_state_machine and _state_machine:
		# StateMachine mode: Return current state name
		return _state_machine.get_current_node()
	else:
		# BlendTree mode: Check OneShot activity and ActionSelect state
		# Try both naming conventions
		var upper_oneshot_param = "parameters/UpperBodyOneShot/active"
		var oneshot_param = "parameters/OneShot/active"
		var fullbody_oneshot_param = "parameters/FullBodyOneShot/active"
		var action_select_param = "parameters/ActionSelect/current_state"
		var transition_param = "parameters/Transition/current_state"
		
		var upper_active = false
		var full_active = false
		var action_state = ""
		
		# Check for OneShot activity with fallback naming
		if _has_parameter(upper_oneshot_param):
			upper_active = _animation_tree.get(upper_oneshot_param)
		elif _has_parameter(oneshot_param):
			upper_active = _animation_tree.get(oneshot_param)
		
		if _has_parameter(fullbody_oneshot_param):
			full_active = _animation_tree.get(fullbody_oneshot_param)
		
		# Check for action state with fallback naming
		if _has_parameter(action_select_param):
			action_state = _animation_tree.get(action_select_param)
		elif _has_parameter(transition_param):
			action_state = _animation_tree.get(transition_param)
		
		if full_active:
			return "FullBodyAction"
		elif upper_active:
			return "UpperBodyAction:" + str(action_state)
		else:
			return "Locomotion"

func get_current_speed() -> float:
	return _current_speed

func get_animation_info() -> Dictionary:
	var info = {
		"current_state": get_current_state(),
		"current_speed": _current_speed,
		"last_action": _last_action_name,
		"last_action_state": _last_action_state,
		"hit_frame_triggered": _hit_frame_triggered,
		"attack_window_active": _active_attack_window,
		"animation_tree_active": _animation_tree.active if _animation_tree else false,
		"mode": "StateMachine" if _use_state_machine else "BlendTree",
		"time_scale": _animation_tree.get("parameters/TimeScale/scale") if _animation_tree else 1.0,
	}
	
	if _use_state_machine:
		info["state_machine_current"] = _state_machine.get_current_node() if _state_machine else ""
		info["state_machine_travel_path"] = _state_machine.get_travel_path() if _state_machine else []
	else:
		info["upper_body_oneshot_active"] = _animation_tree.get("parameters/UpperBodyOneShot/active") if _animation_tree else false
		info["full_body_oneshot_active"] = _animation_tree.get("parameters/FullBodyOneShot/active") if _animation_tree else false
		info["action_select_state"] = _animation_tree.get("parameters/ActionSelect/current_state") if _animation_tree else ""
		info["locomotion_blend"] = _animation_tree.get("parameters/Locomotion/blend_position") if _animation_tree else 0.0
	
	return info

func force_travel_to_state(state_name: StringName) -> void:
	if _use_state_machine and _state_machine:
		# StateMachine mode: Travel directly to the state
		_state_machine.travel(String(state_name))
		if debug_logging:
			print("AnimationController: Force traveled to state: ", state_name)
	else:
		# BlendTree mode: Interpret state names as action requests
		match state_name:
			&"Attack", &"MeleeAttack":
				request_action(&"attack")
			&"RangedAttack":
				request_action(&"ranged_attack") 
			&"Hit", &"OnHit":
				request_action(&"hit")
			&"Throw":
				request_action(&"throw")
			&"Dash":
				request_action(&"dash")
			&"Death":
				request_action(&"death")
			&"Locomotion", &"Idle":
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
	
	# Use appropriate TimeScale parameter based on mode
	var time_scale_param = "parameters/TimeScale/scale"
	if _has_parameter(time_scale_param):
		_animation_tree.set(time_scale_param, 1.0)
		if debug_logging:
			print("AnimationController: Reset TimeScale to normal speed")

## Apply the current attack speed multiplier to the animation tree
func _apply_attack_speed() -> void:
	if not _animation_tree:
		return
	
	# Use TimeScale node for perfect speed control in both systems
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
	
	# Use TimeScale node for perfect speed control in both systems
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
	
	# Use TimeScale node for perfect speed control in both systems
	var time_scale_param = "parameters/TimeScale/scale"
	if _has_parameter(time_scale_param):
		_animation_tree.set(time_scale_param, _enemy_attack_speed_multiplier)
		if debug_logging:
			print("AnimationController: Applied enemy attack speed via TimeScale: ", _enemy_attack_speed_multiplier)
	else:
		if debug_logging:
			print("AnimationController: TimeScale parameter not found!")

# -- Helpers ---------------------------------------------------------------

func _find_animation_tree(node: Node) -> AnimationTree:
	# Search for AnimationTree in the node hierarchy
	if node is AnimationTree:
		return node as AnimationTree
	
	for child in node.get_children():
		var result = _find_animation_tree(child)
		if result:
			return result
	
	return null

func _has_parameter(param_path: String) -> bool:
	if not _animation_tree:
		return false
	var value = _animation_tree.get(param_path)
	return value != null
