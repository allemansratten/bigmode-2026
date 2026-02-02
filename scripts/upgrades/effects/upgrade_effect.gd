extends Node
class_name UpgradeEffect

## Base class for upgrade effects
## Attach as child of TriggerUpgrade
## Override execute() to implement custom effect logic

## Reference to parent TriggerUpgrade
var trigger_upgrade: TriggerUpgrade

## Reference to root BaseUpgrade
var base_upgrade: BaseUpgrade


func _ready() -> void:
	trigger_upgrade = get_parent() as TriggerUpgrade
	if trigger_upgrade:
		base_upgrade = trigger_upgrade.base_upgrade


## VIRTUAL: Override to implement effect logic
## context: Dictionary with event-specific data
##   - "position": Vector3 - where the event occurred
##   - "enemy": Enemy - the enemy involved (for kill/spawn events)
##   - "weapon": Node3D - the weapon involved (for throw/break events)
##   - "player": Player - reference to player
##   - "direction": Vector3 - direction of action (for throw/dash)
##   - "from_position": Vector3 - start position (for teleport)
##   - "to_position": Vector3 - end position (for teleport)
## stacks: Number of times the upgrade has been acquired
func execute(_context: Dictionary, _stacks: int = 1) -> void:
	push_warning("UpgradeEffect.execute() not implemented for %s" % get_script().get_path())


## Helper: Get player from context or find in tree
func get_player(context: Dictionary) -> Node3D:
	if context.has("player"):
		return context["player"]
	return get_tree().get_first_node_in_group("player")


## Helper: Get position from context
func get_position(context: Dictionary) -> Vector3:
	if context.has("position"):
		return context["position"]
	var player = get_player(context)
	if player:
		return player.global_position
	return Vector3.ZERO


## Helper: Get the current room
func get_room() -> Node3D:
	return get_tree().get_first_node_in_group("room")
