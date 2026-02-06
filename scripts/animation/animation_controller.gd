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
## Emitted when attack window opens/closes for weapon systems
signal attack_window(open: bool)
## Emitted when animation events are triggered
signal animation_event(event_name: String, data: Dictionary)

## Animation configuration resource
@export var anim_set: AnimSet

## Enable debug logging for animation state changes
@export var debug_logging: bool = false

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

	_animation_tree = _character.get_node_or_null(anim_set.animation_tree_path)
	if not _animation_tree:
		push_warning("AnimationController: AnimationTree not found at path: ", anim_set.animation_tree_path)
		return

	_animation_tree.active = true

	# Try to get state machine playback (may not exist for pure blend space setups)
	if _has_parameter(anim_set.state_machine_path):
		_state_machine = _animation_tree.get(anim_set.state_machine_path)
		if not _state_machine:
			if debug_logging:
				print("AnimationController: StateMachine not available at path: ", anim_set.state_machine_path)
	else:
		if debug_logging:
			print("AnimationController: StateMachine parameter not found, one-shot actions disabled")

	# Connect AnimationPlayer for animation events
	var anim_player_path = _animation_tree.anim_player
	var anim_player = _animation_tree.get_node_or_null(anim_player_path)
	if anim_player:
		if not anim_player.animation_finished.is_connected(_on_animation_finished):
			anim_player.animation_finished.connect(_on_animation_finished)

	if debug_logging:
		print("AnimationController: Setup complete for ", _character.name)

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

	if _has_parameter(anim_set.locomotion_blend_path):
		_animation_tree.set(anim_set.locomotion_blend_path, blend_position)

		if debug_logging and not is_equal_approx(_current_speed, speed):
			print("AnimationController: Speed=", speed, " Blend=", blend_position)
	elif debug_logging:
		print("AnimationController: Locomotion blend parameter not found: ", anim_set.locomotion_blend_path)

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
	if not _state_machine or not anim_set:
		if debug_logging:
			print("AnimationController: Cannot play action '", action, "' - no state machine available")
		return

	var state_name := anim_set.get_state_for_action(String(action))
	if state_name.is_empty():
		push_warning("AnimationController: No state mapped for action: ", action)
		return

	_last_action_name = action
	_last_action_state = StringName(state_name)
	_hit_frame_triggered = false
	_active_attack_window = false
	# start() jumps immediately, ignoring graph edges and switch_mode delays.
	# travel() is only used for returning to locomotion (where AT_END is desired).
	_state_machine.start(_last_action_state)

	if debug_logging:
		print("AnimationController: Requested action: ", action, " -> ", state_name)

# -- Animation completion --------------------------------------------------

func _on_animation_finished(_animation_name: StringName) -> void:
	if not _state_machine or _last_action_state == &"":
		return

	# Only handle completion if we're still in the action state
	if _state_machine.get_current_node() != _last_action_state:
		return

	_close_attack_window()

	var finished_name = _last_action_name
	_last_action_name = &""
	_last_action_state = &""

	# Stay in terminal states (e.g., death), return to locomotion for everything else
	if not anim_set.is_terminal_action(String(finished_name)):
		_state_machine.travel(anim_set.state_locomotion)

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
	if not _state_machine:
		return "No StateMachine"
	return str(_state_machine.get_current_node())

func get_current_speed() -> float:
	return _current_speed

func get_animation_info() -> Dictionary:
	return {
		"current_state": get_current_state(),
		"current_speed": _current_speed,
		"last_action": _last_action_name,
		"last_state": _last_action_state,
		"hit_frame_triggered": _hit_frame_triggered,
		"attack_window_active": _active_attack_window,
		"animation_tree_active": _animation_tree.active if _animation_tree else false,
		"has_state_machine": _state_machine != null,
	}

func force_travel_to_state(state_name: StringName) -> void:
	if _state_machine:
		_state_machine.travel(state_name)

func force_trigger_event(event_name: String) -> void:
	match event_name:
		"hit_frame":
			_anim_hit_frame()
		"footstep":
			_anim_footstep()
		"attack_window_open":
			_anim_attack_window_open()
		"attack_window_close":
			_anim_attack_window_close()
		_:
			print("AnimationController: Unknown event: ", event_name)

# -- Helpers ---------------------------------------------------------------

func _has_parameter(param_path: String) -> bool:
	if not _animation_tree:
		return false
	var value = _animation_tree.get(param_path)
	return value != null
