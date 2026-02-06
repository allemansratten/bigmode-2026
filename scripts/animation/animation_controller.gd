extends Node
class_name AnimationController

## Universal animation controller for both players and enemies
## Uses speed-based locomotion blending and handles one-shot actions
## Listens to character signals and drives AnimationTree

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
	
	# Connect to TimeScaleManager for bullet time integration  
	if TimeScaleManager.time_scale_changed.is_connected(_on_time_scale_changed):
		TimeScaleManager.time_scale_changed.disconnect(_on_time_scale_changed)
	TimeScaleManager.time_scale_changed.connect(_on_time_scale_changed)
	
	# Register debug commands
	_register_debug_commands()

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

func _connect_character_signals() -> void:
	# Connect to movement and action signals from character
	_connect_signal("started_attacking", _on_start_attacking)
	_connect_signal("took_damage", _on_took_damage)
	_connect_signal("started_dying", _on_start_dying)
	_connect_signal("started_dashing", _on_start_dashing)

func _connect_signal(signal_name: StringName, callback: Callable) -> void:
	if _character.has_signal(signal_name):
		if not _character.is_connected(signal_name, callback):
			_character.connect(signal_name, callback)
	elif debug_logging:
		print("AnimationController: Character missing signal: ", signal_name)

func _process(_delta: float) -> void:
	_update_locomotion_blending()

func _update_locomotion_blending() -> void:
	if not _animation_tree or not anim_set:
		return
		
	# Get current movement speed from character
	var speed = _get_character_speed()
	_current_speed = speed
	
	if anim_set.use_condition_based_locomotion:
		# Use old condition-based system (like current FishDwarf)
		_update_condition_based_locomotion(speed)
	else:
		# Use new blend space system
		_update_blend_space_locomotion(speed)

func _update_condition_based_locomotion(speed: float) -> void:
	var is_moving = anim_set.is_moving_speed(speed)
	
	# Set conditions based on movement state - only if they exist
	if is_moving:
		_set_condition("to_running", true)
	else:
		_set_condition("to_idle", true)
	
	if debug_logging and not is_equal_approx(_current_speed, speed):
		print("AnimationController: Speed=", speed, " Moving=", is_moving)

func _update_blend_space_locomotion(speed: float) -> void:
	# Calculate blend position (0.0 = idle, 1.0 = max speed)
	var blend_position = anim_set.get_blend_position(speed)
	
	# Only set parameter if it exists and AnimationTree is valid
	if _has_parameter(anim_set.locomotion_blend_path):
		_animation_tree.set(anim_set.locomotion_blend_path, blend_position)
		
		if debug_logging and not is_equal_approx(_current_speed, speed):
			print("AnimationController: Speed=", speed, " Blend=", blend_position)
	else:
		if debug_logging:
			print("AnimationController: Locomotion blend parameter not found: ", anim_set.locomotion_blend_path)

## Set condition on AnimationTree (for condition-based locomotion)
func _set_condition(condition_name: String, value: bool) -> void:
	if not _animation_tree:
		return
	
	var condition_path = "parameters/conditions/" + condition_name
	
	# Check if the condition parameter exists before setting it
	if not _has_parameter(condition_path):
		if debug_logging:
			print("AnimationController: Condition parameter not found: ", condition_path)
		return
	
	_animation_tree.set(condition_path, value)
	
	if value:
		# Reset condition after brief moment to allow retriggering
		get_tree().create_timer(0.1).timeout.connect(func(): 
			if _animation_tree and _has_parameter(condition_path):
				_animation_tree.set(condition_path, false)
		)

func _get_character_speed() -> float:
	# First try the dedicated method if available
	if _character.has_method("get_movement_speed"):
		return _character.get_movement_speed()
	
	# Fallback: get speed from velocity (CharacterBody3D)
	if "velocity" in _character:
		var velocity: Vector3 = _character.velocity
		return Vector2(velocity.x, velocity.z).length()
		
	return 0.0

## Request a one-shot action animation
func request_action(action: StringName) -> void:
	if not _state_machine or not anim_set:
		if debug_logging:
			print("AnimationController: Cannot play action '", action, "' - no state machine available")
		return
		
	var target_state: StringName
	match action:
		&"attack":
			target_state = anim_set.state_attack
		&"hit":
			target_state = anim_set.state_hit
		&"dash": 
			target_state = anim_set.state_dash
		&"death":
			target_state = anim_set.state_death
		_:
			push_warning("AnimationController: Unknown action: ", action)
			return
			
	# Check if the target state exists before traveling
	if _state_has_node(target_state):
		_last_action_state = target_state
		_state_machine.travel(target_state)
		
		if debug_logging:
			print("AnimationController: Requested action: ", action, " -> ", target_state)
	else:
		if debug_logging:
			print("AnimationController: State '", target_state, "' not found in StateMachine")

## Signal handlers for character events
func _on_start_attacking() -> void:
	# Reset hit frame tracking for new attack
	_hit_frame_triggered = false
	_active_attack_window = false
	request_action(&"attack")

func _on_took_damage(_amount: float) -> void:
	# Only play hit animation if not already in death state
	if _last_action_state != anim_set.state_death:
		request_action(&"hit")

func _on_start_dying() -> void:
	request_action(&"death")

func _on_start_dashing() -> void:
	request_action(&"dash")

## Handle animation completion from AnimationPlayer
func _on_animation_finished(animation_name: StringName) -> void:
	# Emit completion signals based on animation name
	match animation_name:
		"Attack", "Enemy/Attack", "Player/Attack":
			_emit_completion_signal("attack_animation_finished")
			_close_attack_window()  # Ensure attack window is closed
		"Hit", "Enemy/OnHit", "Player/Hit": 
			_emit_completion_signal("hit_animation_finished")
		"Death", "Enemy/Death", "Player/Death":
			_emit_completion_signal("death_animation_finished")
		"Dash", "Player/Dash":
			_emit_completion_signal("dash_animation_finished")
			
	# Auto-return to locomotion for non-death animations
	if not animation_name.contains("Death"):
		if _state_machine:
			_state_machine.travel(anim_set.state_locomotion)

func _close_attack_window() -> void:
	"""Ensure attack window is properly closed after attack animation"""
	if _active_attack_window:
		_active_attack_window = false
		attack_window.emit(false)

func _emit_completion_signal(signal_name: StringName) -> void:
	if _character.has_signal(signal_name):
		_character.emit_signal(signal_name)

## Handle TimeScaleManager for bullet time compatibility
func _on_time_scale_changed(new_scale: float) -> void:
	# AnimationTree automatically inherits Engine.time_scale
	# Override here if you want specific animations unaffected by bullet time
	pass

## Animation event callbacks (called via AnimationPlayer call method tracks)
func _anim_hit_frame() -> void:
	if not _hit_frame_triggered:
		_hit_frame_triggered = true
		hit_frame.emit()
		animation_event.emit("hit_frame", {"attack_state": _last_action_state})
		
		# Apply weapon damage if character has active weapon
		_trigger_weapon_hit()

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

## Trigger weapon damage during hit frame
func _trigger_weapon_hit() -> void:
	# Try to find and trigger weapon damage
	if _character.has_method("get_active_weapon"):
		var weapon = _character.get_active_weapon()
		if weapon and weapon.has_method("apply_hit_frame_damage"):
			weapon.apply_hit_frame_damage()
			return
	
	# Fallback: look for inventory system
	var inventory = _character.get_node_or_null("PlayerInventory")
	if inventory and inventory.has_method("get_active_weapon"):
		var weapon = inventory.get_active_weapon()
		if weapon and weapon.has_method("trigger_hit_frame"):
			weapon.trigger_hit_frame()
		else:
			# For backwards compatibility with existing weapons
			if weapon and weapon.has_method("_process_hit_detection"):
				weapon._process_hit_detection(0.0)  # Manual hit detection trigger

## Debug methods (for DebugConsole integration)
func get_current_state() -> String:
	if not _state_machine:
		return "No StateMachine"
	return str(_state_machine.get_current_node())

func get_current_speed() -> float:
	return _current_speed

func get_animation_info() -> Dictionary:
	"""Get comprehensive animation state for debugging"""
	return {
		"current_state": get_current_state(),
		"current_speed": _current_speed,
		"last_action": _last_action_state,
		"hit_frame_triggered": _hit_frame_triggered,
		"attack_window_active": _active_attack_window,
		"animation_tree_active": _animation_tree.active if _animation_tree else false,
		"has_state_machine": _state_machine != null
	}

func force_travel_to_state(state_name: StringName) -> void:
	if _state_machine:
		_state_machine.travel(state_name)

func force_trigger_event(event_name: String) -> void:
	"""Manually trigger animation events for testing"""
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

## Helper methods for parameter validation
func _has_parameter(param_path: String) -> bool:
	if not _animation_tree:
		return false
	
	# Try to access the parameter - if it doesn't exist, this will return null
	var value = _animation_tree.get(param_path)
	return value != null

func _state_has_node(node_name: StringName) -> bool:
	if not _state_machine:
		return false
	
	# Check if the state machine has this node
	# This is a simple check - in a real implementation you might want to 
	# inspect the StateMachine's states more thoroughly
	var current_node = _state_machine.get_current_node()
	return current_node != null  # Basic check - improve if needed

func _register_debug_commands() -> void:
	"""Register debug console commands for animation testing"""
	if not DebugConsole:
		return
		
	DebugConsole.register_command("anim_state", "Show current animation state")
	DebugConsole.register_command("anim_travel", "Travel to animation state: /anim_travel <state>")
	DebugConsole.register_command("anim_event", "Trigger animation event: /anim_event <event>")
	DebugConsole.register_command("anim_info", "Show detailed animation info")
	DebugConsole.register_command("anim_speed", "Set animation speed: /anim_speed <multiplier>")
	
	if not DebugConsole.command_entered.is_connected(_on_debug_command):
		DebugConsole.command_entered.connect(_on_debug_command)

func _on_debug_command(cmd: String, args: PackedStringArray) -> void:
	"""Handle debug console commands"""
	match cmd:
		"anim_state":
			var state = get_current_state()
			DebugConsole.debug_log("Animation State: " + state)
		"anim_travel":
			if args.size() > 0:
				var state_name = StringName(args[0])
				force_travel_to_state(state_name)
				DebugConsole.debug_log("Traveling to state: " + String(state_name))
			else:
				DebugConsole.debug_log("Usage: anim_travel <state_name>")
		"anim_event":
			if args.size() > 0:
				var event_name = args[0]
				force_trigger_event(event_name)
				DebugConsole.debug_log("Triggered event: " + event_name)
			else:
				DebugConsole.debug_log("Usage: anim_event <event_name>")
		"anim_info":
			var info = get_animation_info()
			for key in info:
				DebugConsole.debug_log(key + ": " + str(info[key]))
		"anim_speed":
			if args.size() > 0:
				var multiplier = float(args[0])
				if _animation_tree:
					_animation_tree.speed_scale = multiplier
					DebugConsole.debug_log("Animation speed set to: " + str(multiplier))
			else:
				DebugConsole.debug_log("Usage: anim_speed <multiplier>")