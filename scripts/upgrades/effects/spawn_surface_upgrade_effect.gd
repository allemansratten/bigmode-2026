extends UpgradeEffect
class_name SpawnSurfaceUpgradeEffect

## Spawns a surface (oil, ice, water) at the event position
## Attach as child of TriggerUpgrade

## Surface scene to spawn
@export var surface_scene: PackedScene

## Offset from event position
@export var spawn_offset: Vector3 = Vector3(0, 0.05, 0)

## Use "from_position" for teleport (origin) vs "position" (default)
@export var use_from_position: bool = false

## Surface lifetime in seconds (0 = use surface default)
@export var lifetime: float = 3.0


func execute(context: Dictionary, _stacks: int = 1) -> void:
	if not surface_scene:
		push_warning("SpawnSurfaceUpgradeEffect: no surface_scene assigned")
		return

	# Get spawn position from context
	var spawn_pos: Vector3
	if use_from_position and context.has("from_position"):
		spawn_pos = context["from_position"]
	else:
		spawn_pos = get_position(context)

	spawn_pos += spawn_offset

	# Find room to add surface to
	var room = get_room()
	if not room:
		push_warning("SpawnSurfaceUpgradeEffect: no room found")
		return

	# Instance and spawn surface
	var surface = surface_scene.instantiate()
	room.add_child(surface)
	surface.global_position = spawn_pos

	# Set lifetime if surface supports it
	if lifetime > 0.0 and "lifetime" in surface:
		surface.lifetime = lifetime

	print("SpawnSurfaceUpgradeEffect: spawned %s at %s" % [surface.name, spawn_pos])
