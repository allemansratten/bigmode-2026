extends 'res://scripts/items/effects/on_destroy_effect.gd'
class_name ExplosionEffect

## Spawns an explosion when the item is destroyed
## Attach to any throwable item to make it explode on impact

## Explosion radius for damage/knockback
@export var explosion_radius: float = 3.0
## Damage dealt at explosion center
@export var explosion_damage: float = 30.0
## Knockback force applied to entities
@export var knockback_force: float = 10.0


func execute() -> void:
	print("ExplosionEffect: spawning explosion at %s (radius: %s, damage: %s)" % [item.global_position, explosion_radius, explosion_damage])

	# TODO: Find all entities in explosion_radius
	# TODO: Apply damage based on distance from center
	# TODO: Apply knockback force
	# TODO: Spawn explosion particles
	# TODO: Play explosion sound
	# TODO: Apply screen shake
