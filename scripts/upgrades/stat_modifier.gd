class_name StatModifier
extends Resource

## Defines a single stat modification for weapons
## Used by WeaponModifierUpgrade to specify what stats to change

enum Operation {
	ADD,       # Add value to stat
	MULTIPLY,  # Multiply stat by (1 + value)
}

enum Stat {
	# Common weapon stats
	DAMAGE,
	MAX_DURABILITY,
	DURABILITY,        # Current durability (for spawning with bonus)
	ATTACK_COOLDOWN,

	# Melee-specific stats
	SWING_RANGE,
	SWING_ANGLE,
	KNOCKBACK_FORCE,

	# Ranged-specific stats
	PROJECTILE_SPEED,
	SPREAD,
	MAX_AMMO,
}

## Which stat to modify
@export var stat: Stat = Stat.DAMAGE

## How to apply the modification
@export var operation: Operation = Operation.ADD

## The value to add or multiply by
@export var value: float = 0.0


## Apply this modifier to a weapon behaviour
## stacks: number of times the upgrade has been acquired
func apply(weapon: WeaponBehaviour, stacks: int = 1) -> void:
	var effective_value = value * stacks

	match stat:
		Stat.DAMAGE:
			_apply_to_property(weapon, "damage", effective_value)
		Stat.MAX_DURABILITY:
			_apply_to_property(weapon, "max_durability", effective_value)
		Stat.DURABILITY:
			_apply_to_property(weapon, "current_durability", effective_value)
		Stat.ATTACK_COOLDOWN:
			_apply_to_property(weapon, "attack_cooldown", effective_value)
		Stat.SWING_RANGE:
			if weapon is MeleeWeaponBehaviour:
				_apply_to_property(weapon, "swing_range", effective_value)
		Stat.SWING_ANGLE:
			if weapon is MeleeWeaponBehaviour:
				_apply_to_property(weapon, "swing_angle", effective_value)
		Stat.KNOCKBACK_FORCE:
			if weapon is MeleeWeaponBehaviour:
				_apply_to_property(weapon, "knockback_force", effective_value)
		Stat.PROJECTILE_SPEED:
			if weapon is RangedWeaponBehaviour:
				_apply_to_property(weapon, "projectile_speed", effective_value)
		Stat.SPREAD:
			if weapon is RangedWeaponBehaviour:
				_apply_to_property(weapon, "spread", effective_value)
		Stat.MAX_AMMO:
			if weapon is RangedWeaponBehaviour:
				_apply_to_property(weapon, "max_ammo", effective_value)


func _apply_to_property(obj: Object, property: String, effective_value: float) -> void:
	if not obj.get(property):
		return

	var current = obj.get(property)
	var new_value: float

	if operation == Operation.ADD:
		new_value = current + effective_value
	else:  # MULTIPLY
		new_value = current * (1.0 + effective_value)

	# Handle integer properties
	if current is int:
		obj.set(property, int(new_value))
	else:
		obj.set(property, new_value)
