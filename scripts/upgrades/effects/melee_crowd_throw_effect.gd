extends UpgradeEffect
class_name MeleeCrowdThrowEffect

## Triggers crowd throwing only when a melee weapon is thrown
## Extends CrowdThrowEffect with melee weapon filtering

## Categories the thrown item must match (uses matches_any)
@export var item_categories: Array[ItemCategories.Category] = []

func execute(context: Dictionary, _stacks: int = 1) -> void:
	# Check if thrown weapon is a melee weapon
	if not context.has("weapon"):
		return
	
	var weapon = context["weapon"]
	if not weapon:
		return
	
	# Check if weapon has MeleeWeaponBehaviour
	var has_melee_behaviour = false
	for child in weapon.get_children():
		if child.get_script() and child.get_script().get_global_name() == "MeleeWeaponBehaviour":
			has_melee_behaviour = true
			break
	
	if not has_melee_behaviour:
		DebugConsole.debug_log("MeleeCrowdThrowEffect: Skipped - weapon is not melee")
		return
	
	# Trigger crowd throw
	EventBus.crowd_throw_requested.emit(item_categories, 1.0)
	DebugConsole.debug_log("MeleeCrowdThrowEffect: Triggered crowd throw for melee weapon")