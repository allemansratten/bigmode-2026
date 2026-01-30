extends Node3D
class_name CrowdMember

## Individual crowd member NPC
## Represents a single person in the crowd with basic visual representation

## Optional: Animation state for future use
@export var animation_state: String = "idle"

## Optional: Variation seed for randomizing appearance
@export var variation_seed: int = 0


func _ready() -> void:
	# Apply visual variations based on seed
	if variation_seed > 0:
		_apply_variation()


func _apply_variation() -> void:
	"""Apply random variations to appearance based on seed"""
	# TODO: Randomize colors, scale, rotation slightly
	pass
