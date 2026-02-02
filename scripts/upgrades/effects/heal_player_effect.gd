extends UpgradeEffect
class_name HealPlayerEffect

## Heals the player when triggered
## Attach as child of TriggerUpgrade

## Amount to heal (flat value)
@export var heal_amount: float = 5.0

## Heal as percentage of max health (0 = use flat amount)
@export var heal_percent: float = 0.0

## Whether stacks increase the heal amount
@export var scales_with_stacks: bool = true


func execute(context: Dictionary, stacks: int = 1) -> void:
	var player = get_player(context)
	if not player:
		push_warning("HealPlayerEffect: no player found")
		return

	# Calculate heal amount
	var amount = heal_amount
	if heal_percent > 0.0 and player.has_method("get") and player.get("max_health"):
		amount = player.max_health * heal_percent

	if scales_with_stacks:
		amount *= stacks

	# Apply healing
	if player.has_method("heal"):
		player.heal(amount)
	elif "current_health" in player and "max_health" in player:
		player.current_health = minf(player.current_health + amount, player.max_health)
		if player.has_signal("health_changed"):
			player.health_changed.emit(player.current_health, player.max_health)

	print("HealPlayerEffect: healed player for %.1f" % amount)
