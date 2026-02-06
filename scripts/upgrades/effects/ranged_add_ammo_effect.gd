extends UpgradeEffect
class_name RangedAddAmmoEffect

## Adds ammo to ranged weapons when triggered, with ranged weapon filtering
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
			if child.get_script() and child.get_script().get_global_name() == "RangedWeaponBehaviour":
				ranged_behaviour = child
				break
	
	if not ranged_behaviour:
		DebugConsole.debug_log("RangedAddAmmoEffect: Skipped - weapon is not ranged")
		return
	
	if ranged_behaviour.has_method("reload"):
		ranged_behaviour.reload(ammo_amount)
		DebugConsole.debug_log("RangedAddAmmoEffect: Added %d ammo to %s" % [ammo_amount, weapon.name])