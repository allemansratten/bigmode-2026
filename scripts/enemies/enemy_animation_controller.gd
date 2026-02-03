extends Node
class_name EnemyAnimationController

## Simple animation controller for enemies
## Listens to enemy signals and sets AnimationTree conditions

# Animation Tree reference
var animation_tree: AnimationTree


func _ready():
	# Find AnimationTree in enemy model
	_find_animation_tree()
	
	# Connect to enemy signals
	_connect_to_enemy_signals()


func _find_animation_tree():
	var enemy = get_parent()
	if not enemy:
		push_warning("EnemyAnimationController needs a parent enemy")
		return
	
	# Look for AnimationTree in child nodes (like FishDwarf model)
	animation_tree = _find_child_recursive(enemy, "AnimationTree")
	
	if animation_tree:
		animation_tree.active = true
		
		# Connect to animation completion signals
		var anim_player_node = animation_tree.get_node_or_null(animation_tree.anim_player)
		if anim_player_node:
			anim_player_node.animation_finished.connect(_on_animation_finished)
		else:
			push_warning("AnimationPlayer not found at path: ", animation_tree.anim_player)
	else:
		push_warning("No AnimationTree found for enemy: ", enemy.name)


func _find_child_recursive(node: Node, target_name: String) -> Node:
	for child in node.get_children():
		if child.name == target_name or child.get_class() == target_name:
			return child
		var result = _find_child_recursive(child, target_name)
		if result:
			return result
	return null


func _connect_to_enemy_signals():
	var enemy = get_parent()
	if not enemy:
		return
	
	# Connect to enemy signals
	if enemy.has_signal("started_moving"):
		enemy.started_moving.connect(_on_start_moving)
		
	if enemy.has_signal("stopped_moving"):
		enemy.stopped_moving.connect(_on_stop_moving)
		
	if enemy.has_signal("started_attacking"):
		enemy.started_attacking.connect(_on_start_attacking)
		
	if enemy.has_signal("took_damage"):
		enemy.took_damage.connect(_on_took_damage)
		
	if enemy.has_signal("started_dying"):
		enemy.started_dying.connect(_on_start_dying)

## Signal handlers - just set AnimationTree conditions
func _on_start_moving():
	_set_condition("to_running", true)


func _on_stop_moving():
	_set_condition("to_idle", true)


func _on_start_attacking():
	_set_condition("to_attack", true)


func _on_took_damage(_amount: float):
	_set_condition("to_onhit", true)


func _on_start_dying():
	_set_condition("to_death", true)


## Set condition on AnimationTree
func _set_condition(condition_name: String, value: bool):
	if not animation_tree:
		push_warning("No AnimationTree available to set condition: ", condition_name)
		return
	
	var condition_path = "parameters/conditions/" + condition_name
	animation_tree.set(condition_path, value)
	
	if value and condition_name != "to_death":
		# Reset condition after brief moment to allow retriggering
		# Don't reset death condition - death is permanent
		get_tree().create_timer(0.1).timeout.connect(func(): 
			animation_tree.set(condition_path, false)
		)


## Handle animation completion from AnimationPlayer
func _on_animation_finished(animation_name: StringName):
	var enemy = get_parent()
	if not enemy:
		return
	
	# Emit corresponding completion signals
	match animation_name:
		"Enemy/Attack":
			if enemy.has_signal("attack_animation_finished"):
				enemy.emit_signal("attack_animation_finished")
		"Enemy/OnHit":
			if enemy.has_signal("hit_animation_finished"):
				enemy.emit_signal("hit_animation_finished")
		"Enemy/Death":
			if enemy.has_signal("death_animation_finished"):
				enemy.emit_signal("death_animation_finished")



