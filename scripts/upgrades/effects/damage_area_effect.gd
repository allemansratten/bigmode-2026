extends UpgradeEffect
class_name DamageAreaEffect

## Deals damage to all enemies in a radius around the event position
## Attach as child of TriggerUpgrade

## Damage dealt to each enemy
@export var damage: float = 1.0

## Radius of the damage area
@export var radius: float = 3.0

## Whether stacks increase damage
@export var scales_with_stacks: bool = true


func execute(context: Dictionary, stacks: int = 1) -> void:
	var position = get_position(context)
	if position == Vector3.ZERO:
		push_warning("DamageAreaEffect: no valid position")
		return

	var effective_damage = damage
	if scales_with_stacks:
		effective_damage *= stacks

	# Find all enemies in radius
	var enemies = get_tree().get_nodes_in_group("enemy")
	var hit_count = 0

	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy is Node3D:
			continue

		var distance = position.distance_to(enemy.global_position)
		if distance <= radius:
			if enemy.has_method("take_damage"):
				var player = get_player(context)
				enemy.take_damage(effective_damage, player)
				hit_count += 1

	if hit_count > 0:
		print("DamageAreaEffect: hit %d enemies for %.1f damage each" % [hit_count, effective_damage])
