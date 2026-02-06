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

## Animation state names in the AnimationTree
@export_group("Animation States")
## Base locomotion state in StateMachine (contains BlendSpace1D)
@export var state_locomotion: StringName = &"Locomotion"
## One-shot action states
@export var state_attack: StringName = &"Attack" 
@export var state_hit: StringName = &"Hit"
@export var state_dash: StringName = &"Dash"
@export var state_death: StringName = &"Death"

## Get normalized speed for blend position (0.0 = idle, 1.0 = max speed)
func get_blend_position(speed: float) -> float:
	return clamp(speed / max_movement_speed, 0.0, 1.0)

## Check if speed qualifies as "moving" (above idle threshold)
func is_moving_speed(speed: float) -> bool:
	return speed >= idle_to_walk_speed