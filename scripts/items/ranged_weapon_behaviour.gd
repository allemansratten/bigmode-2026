extends "res://scripts/items/weapon_behaviour.gd"
class_name RangedWeaponBehaviour

## Ranged weapon behavior for projectile-based attacks
## Spawns projectiles when attacking

## Projectile scene to spawn
@export var projectile_scene: PackedScene
## Speed of spawned projectiles
@export var projectile_speed: float = 20.0
## Current ammo count (-1 for infinite)
@export var ammo_count: int = -1
## Maximum ammo capacity
@export var max_ammo: int = 30
## Accuracy spread in degrees (0 = perfect accuracy)
@export var spread: float = 0.0
## Offset from weapon position to spawn projectile
@export var projectile_spawn_offset: Vector3 = Vector3(0, 0, -0.5)
## Debug projectile spawning
@export var debug_projectiles: bool = false
## Sound to play when attack starts
@export var attack_sound: AudioStream
## Delay before playing attack sound
@export var attack_sound_delay: float = 0.0


## Override attack to spawn projectile
func _attack() -> void:
    if not item:
        print("ERROR: RangedWeaponBehaviour: no item reference!")
        return

    if debug_projectiles:
        print("DEBUG: RangedWeaponBehaviour: attack called on ", item.name)
        print("DEBUG: Item position: ", item.global_position)

    # Check ammo
    if ammo_count == 0:
        FloatingText.spawn(item.get_tree(), item.global_position + Vector3.UP, "No ammo!", Color.WHITE)
        return

    if not projectile_scene:
        push_warning("RangedWeaponBehaviour: no projectile_scene set for ", item.name)
        return

    # Get attack direction towards mouse cursor from player's center (with height offset)
    var player = item.get_tree().get_first_node_in_group("player")
    var attack_origin = player.global_position + Vector3.UP * 1.0 if player else item.global_position
    var attack_direction = _get_mouse_direction(attack_origin)
    var spawn_position = attack_origin + attack_direction.normalized() * projectile_spawn_offset.length()

    if debug_projectiles:
        print("DEBUG: Attack origin: ", attack_origin)
        print("DEBUG: Mouse direction: ", attack_direction)
        print("DEBUG: Spawn position: ", spawn_position)

    # Apply spread
    if spread > 0.0:
        var spread_x = randf_range(-spread, spread)
        var spread_y = randf_range(-spread, spread)
        attack_direction = attack_direction.rotated(Vector3.UP, deg_to_rad(spread_x))
        attack_direction = attack_direction.rotated(Vector3.RIGHT, deg_to_rad(spread_y))
        
        if debug_projectiles:
            print("DEBUG: Applied spread - X:", spread_x, " Y:", spread_y)

    attack_direction = attack_direction.normalized()
    
    if debug_projectiles:
        print("DEBUG: Final attack direction: ", attack_direction)

    # Check for immediate collisions at spawn point
    var space_state = item.get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(spawn_position, spawn_position + attack_direction * 0.1)
    var immediate_collision = space_state.intersect_ray(query)
    
    if immediate_collision and debug_projectiles:
        print("WARNING: Immediate collision detected at spawn point!")
        print("WARNING: Colliding with: ", immediate_collision.get("collider", "unknown"))
        print("WARNING: Collision point: ", immediate_collision.get("position", "unknown"))

    # Play attack sound
    if attack_sound:
        if attack_sound_delay > 0.0:
            get_tree().create_timer(attack_sound_delay).timeout.connect(func(): Audio.play_sound(attack_sound, Audio.Channels.SFX))
        else:
            Audio.play_sound(attack_sound, Audio.Channels.SFX)

    # Spawn projectile
    var projectile = projectile_scene.instantiate()
    item.get_tree().root.add_child(projectile)
    
    # Set position first, then wait a frame to avoid immediate parent collision
    projectile.global_position = spawn_position
    
    if debug_projectiles:
        print("DEBUG: Projectile spawned at: ", projectile.global_position)
        print("DEBUG: Projectile scene: ", projectile_scene.resource_path)

    # Check if projectile has collision layers set properly
    if projectile is RigidBody3D or projectile is CharacterBody3D:
        if debug_projectiles:
            print("DEBUG: Projectile collision_layer: ", projectile.collision_layer)
            print("DEBUG: Projectile collision_mask: ", projectile.collision_mask)
            print("DEBUG: Item collision_layer: ", item.collision_layer)

    # Initialize projectile with direction and damage
    if projectile.has_method("initialize"):
        if debug_projectiles:
            print("DEBUG: Calling projectile.initialize with direction: ", attack_direction)
        projectile.initialize(attack_direction, item, damage)
    elif projectile is RigidBody3D:
        # Fallback for RigidBody3D projectiles
        if debug_projectiles:
            print("DEBUG: Setting RigidBody3D linear_velocity: ", attack_direction * projectile_speed)
        projectile.linear_velocity = attack_direction * projectile_speed
    else:
        push_warning("RangedWeaponBehaviour: Unknown projectile type for ", item.name)

    # Consume ammo
    if ammo_count > 0:
        ammo_count -= 1
        if debug_projectiles:
            print("DEBUG: Ammo consumed, remaining: ", ammo_count)


## Get attack direction towards mouse cursor (copied from MeleeWeaponBehaviour)
func _get_mouse_direction(from_position: Vector3) -> Vector3:
    var viewport = item.get_viewport()
    var camera = viewport.get_camera_3d()
    if not camera:
        # Fallback to forward direction if no camera
        return -item.global_transform.basis.z

    var mouse_pos = viewport.get_mouse_position()

    # Cast ray from camera through mouse position
    var ray_origin = camera.project_ray_origin(mouse_pos)
    var ray_direction = camera.project_ray_normal(mouse_pos)

    # Project onto XZ plane (ground level)
    var y_level = from_position.y
    if abs(ray_direction.y) > 0.001:
        var t = (y_level - ray_origin.y) / ray_direction.y
        var hit_point = ray_origin + ray_direction * t

        # Calculate direction from attack origin to hit point
        var direction = (hit_point - from_position).normalized()
        return direction

    # Fallback: use ray direction flattened to XZ
    return Vector3(ray_direction.x, 0, ray_direction.z).normalized()


## Debug function to test spawn position without firing
func debug_spawn_position() -> void:
    if not item:
        return
        
    var attack_origin = item.global_position
    var attack_direction = _get_mouse_direction(attack_origin)
    var spawn_pos = attack_origin + attack_direction.normalized() * projectile_spawn_offset.length()
    
    print("DEBUG: Would spawn at: ", spawn_pos)
    print("DEBUG: Attack direction: ", attack_direction)
    
    # Visual debug - create temporary marker
    var marker = MeshInstance3D.new()
    marker.mesh = SphereMesh.new()
    marker.mesh.radius = 0.1
    item.get_tree().root.add_child(marker)
    marker.global_position = spawn_pos
    
    # Remove marker after 2 seconds
    var timer = Timer.new()
    timer.wait_time = 2.0
    timer.one_shot = true
    timer.timeout.connect(func():
        if marker and is_instance_valid(marker):
            marker.queue_free()
        if timer and is_instance_valid(timer):
            timer.queue_free()
    )
    item.get_tree().root.add_child(timer)
    timer.start()


## Fire a projectile in a specific direction (used by upgrades like Smart Weapons)
func fire_in_direction(direction: Vector3) -> void:
    var spawn_position = item.global_position + Vector3.UP * 0.5
    var attack_direction = direction.normalized()

    # Apply spread
    if spread > 0.0:
        var spread_x = randf_range(-spread, spread)
        var spread_y = randf_range(-spread, spread)
        attack_direction = attack_direction.rotated(Vector3.UP, deg_to_rad(spread_x))
        attack_direction = attack_direction.rotated(Vector3.RIGHT, deg_to_rad(spread_y))
    attack_direction = attack_direction.normalized()

    # Play attack sound
    if attack_sound:
        Audio.play_sound(attack_sound, Audio.Channels.SFX)

    # Spawn projectile
    var projectile = projectile_scene.instantiate()
    item.get_tree().root.add_child(projectile)
    projectile.global_position = spawn_position

    # Initialize projectile
    if projectile.has_method("initialize"):
        projectile.initialize(attack_direction, item, damage)
    elif projectile is RigidBody3D:
        projectile.linear_velocity = attack_direction * projectile_speed

    # Consume ammo
    if ammo_count > 0:
        ammo_count -= 1


## Reload ammo
func reload(amount: int = -1) -> void:
    if amount < 0:
        ammo_count = max_ammo
    else:
        ammo_count = min(max_ammo, ammo_count + amount)

    print("RangedWeaponBehaviour: reloaded to ", ammo_count, " ammo")


## Check if weapon has ammo
func has_ammo() -> bool:
    return ammo_count != 0
