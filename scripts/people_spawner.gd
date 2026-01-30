@tool
extends Node3D
class_name PeopleSpawner

## Spawns NPCs in a defined rectangular area
## The spawner will dynamically fill the spawn area with crowd members

## The rectangular spawn area dimensions
@export var spawn_area_size: Vector2 = Vector2(8, 6):
	set(value):
		spawn_area_size = value
		update_gizmos()

## Spacing between NPCs
@export var spacing: float = 1.0

## Height offset for spawning NPCs
@export var spawn_height: float = 0.0:
	set(value):
		spawn_height = value
		update_gizmos()

## Optional: NPC scene to spawn (for future use)
@export var npc_scene: PackedScene = null

## Debug visualization color
@export var debug_color: Color = Color.YELLOW


func _ready() -> void:
	# Will implement spawning logic here
	pass


func spawn_crowd() -> void:
	"""Spawns NPCs in the defined area"""
	# TODO: Implement crowd spawning logic
	# - Calculate grid positions based on spawn_area_size and spacing
	# - Instantiate NPC scenes at each position
	# - Add variation to prevent uniform look
	pass


func _draw_debug() -> void:
	"""Visualize spawn area in editor (gizmo)"""
	pass
