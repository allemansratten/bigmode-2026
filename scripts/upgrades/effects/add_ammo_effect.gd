extends UpgradeEffect
class_name AddAmmoEffect

## Adds ammo to ranged weapons when triggered
## Used for "When you throw a ranged weapon, add 1 ammo to it"

## Amount of ammo to add
@export var ammo_amount: int = 1

func execute(context: Dictionary, _stacks: int = 1) -> void:
	if not context.has("weapon"):
		return
	
	var weapon = context["weapon"]
	if not weapon:
		return
	
	# Find RangedWeaponBehaviour component
	var ranged_behaviour = weapon.get_node_or_null("RangedWeaponBehaviour")
	if not ranged_behaviour:
		# Try as direct child
		for child in weapon.get_children():
			if child is RangedWeaponBehaviour:
				ranged_behaviour = child
				break
	
	if ranged_behaviour and ranged_behaviour.has_method("reload"):
		ranged_behaviour.reload(ammo_amount)
		DebugConsole.debug_log("AddAmmoEffect: Added %d ammo to %s" % [ammo_amount, weapon.name])