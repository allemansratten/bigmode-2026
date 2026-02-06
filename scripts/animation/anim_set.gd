class_name AnimSet
extends Resource

## Data-driven animation configuration for characters
## Defines animation states, speed thresholds, and AnimationTree paths

## Path to the AnimationTree node relative to the character root
@export var animation_tree_path: NodePath = ^"AnimationTree"

## Locomotion blend configuration
@export_group("Locomotion Blending")
## Speed threshold where idle transitions to walk (m/s)
@export var idle_to_walk_speed: float = 0.5
## Speed threshold where walk transitions to run (m/s)
@export var walk_to_run_speed: float = 3.0
## Maximum movement speed for normalizing blend values (1.0 = full sprint)
@export var max_movement_speed: float = 6.0

## AnimationTree parameter paths
@export_group("Animation Tree Paths")
## Path to locomotion blend parameter (BlendSpace1D) - leave empty if using conditions
@export var locomotion_blend_path: String = "parameters/Locomotion/blend_position"
## Path to state machine playback for actions
@export var state_machine_path: String = "parameters/playback"
## Use condition-based state machine instead of blend space
@export var use_condition_based_locomotion: bool = false

## State mapping
@export_group("State Mapping")
## Base locomotion state in StateMachine
@export var state_locomotion: StringName = &"Locomotion"
## Maps action names to AnimationTree state machine node names
## Example: {"attack": "Attack", "hit": "OnHit", "death": "Death"}
@export var action_states: Dictionary[String, String] = {
	"attack": "Attack",
	"hit": "Hit",
	"dash": "Dash",
	"death": "Death",
}
## Actions that don't auto-return to locomotion when finished (e.g., death)
@export var terminal_actions: PackedStringArray = ["death"]

## Signal mapping
@export_group("Signal Mapping")
## Maps character signal names to action names
## Controller auto-connects these at _ready(), ignoring signals that don't exist
## Example: {"started_attacking": "attack", "took_damage": "hit"}
@export var signal_actions: Dictionary[String, String] = {
	"started_attacking": "attack",
	"took_damage": "hit",
	"started_dying": "death",
	"started_dashing": "dash",
}

## Get normalized speed for blend position (0.0 = idle, 1.0 = max speed)
func get_blend_position(speed: float) -> float:
	return clamp(speed / max_movement_speed, 0.0, 1.0)

## Check if speed qualifies as "moving" (above idle threshold)
func is_moving_speed(speed: float) -> bool:
	return speed >= idle_to_walk_speed

## Get the state machine node name for an action, or empty string if unmapped
func get_state_for_action(action: String) -> String:
	return action_states.get(action, "")

## Check if an action is terminal (stays in state, no return to locomotion)
func is_terminal_action(action: String) -> bool:
	return action in terminal_actions
