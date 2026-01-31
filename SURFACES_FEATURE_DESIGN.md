# Surface System Design

## Overview
Implement a surface system where weapons and effects can spawn environmental hazards (oil, ice, water) that affect entity movement and behavior. Surfaces persist as children of rooms, stack vertically with priority, and have configurable lifetimes.

## Architecture

### Core Components

1. **Surface (Base Class)**
   - Node3D with Area3D for spatial presence
   - Visual representation (puddle mesh)
   - Surface type enum (OIL, ICE, WATER)
   - Lifetime system (persistent vs timed)
   - Y-position for stacking priority
   - Parent: Room node

2. **SurfaceEffect (Resource)**
   - Data container for surface behavior
   - Movement speed multiplier (oil: 0.5, ice: 1.2, water: 1.0)
   - Friction/control modifier (oil: sticky, ice: slippery)
   - Status effects (future: damage over time, slow)
   - Effect parameters (intensity, duration)

3. **SurfaceDetector (Component)**
   - Attached to entities (Player, Enemy)
   - Performs downward raycast to detect surface
   - Queries Room for surfaces at position
   - Returns top-most surface (highest Y)
   - Configurable detection rate (every 0.1s)

4. **Room Integration**
   - Room maintains array of active surfaces
   - Provides `get_surface_at_position(pos: Vector3) -> Surface`
   - Returns highest surface within radius
   - Handles surface cleanup when room unloaded

### Surface Types

#### Oil Surface
- **Effect**: Sticky/slow movement (50% speed)
- **Visual**: Dark brown/black puddle
- **Lifetime**: Persistent (until cleaned)
- **Spawned by**: Oil Flask (throwable item)
- **Future**: Can be ignited by fire

#### Ice Surface
- **Effect**: Fast movement (120% speed)
- **Visual**: Light blue/white icy puddle
- **Lifetime**: Timed (30 seconds)
- **Spawned by**: Ice spell/weapon (future)
- **Future**: Can be melted by fire
- **TODO**: Add sliding momentum (reduced control/direction changes)

#### Water Surface
- **Effect**: No movement effect (neutral)
- **Visual**: Blue/transparent puddle
- **Lifetime**: Timed (20 seconds)
- **Spawned by**: Water flask (future)
- **Special**: Instantly cleans/deletes other surfaces (removes oil/ice when overlapping)

### Stacking System

When multiple surfaces overlap:
1. Entity detector finds all surfaces at position
2. Returns surface with highest Y-position
3. Only top surface applies its effect
4. Lower surfaces remain but are inactive

**Example**: Oil puddle (Y: 0.01) + Water puddle (Y: 0.02) = Water effect applies

### Detection System

**Raycast approach** - Entities check if their center point is over a surface:

```gdscript
# SurfaceDetector component
func _detect_surface():
    var ray_origin = entity.global_position + Vector3.UP * 0.5
    var ray_end = ray_origin + Vector3.DOWN * 2.0

    # Raycast down from entity center
    var space_state = entity.get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
    query.collision_mask = collision_layer_for_surfaces

    var result = space_state.intersect_ray(query)
    if result:
        var surface = result.collider.get_parent() # Assumes collider is Area3D child of Surface
        if surface is Surface:
            apply_surface_effect(surface)

# Alternative: Room query with center point check
func _detect_surface_via_room():
    var room = get_tree().get_first_node_in_group("room")
    var surface = room.get_top_surface_at_position(entity.global_position)
    if surface:
        apply_surface_effect(surface)
```

**Room helper method:**
```gdscript
# Room.gd
func get_top_surface_at_position(pos: Vector3) -> Surface:
    var top_surface: Surface = null
    var max_y = -INF

    for surface in active_surfaces:
        # Check if position is within surface radius (XZ plane)
        var surface_pos_xz = Vector2(surface.global_position.x, surface.global_position.z)
        var check_pos_xz = Vector2(pos.x, pos.z)
        var distance = surface_pos_xz.distance_to(check_pos_xz)

        if distance <= surface.radius and surface.global_position.y > max_y:
            top_surface = surface
            max_y = surface.global_position.y

    return top_surface
```

**Design decision**: Use Room query approach (simpler, no collision layer setup needed). Raycast checks if entity center is within surface radius on XZ plane.

## File Structure

```
scenes/
  surfaces/
    OilSurface.tscn       # Oil puddle scene
    IceSurface.tscn       # Ice puddle scene
    WaterSurface.tscn     # Water puddle scene

scripts/
  surfaces/
    surface.gd                # Base surface class
    surface_effect.gd         # Effect resource
    surface_detector.gd       # Detection component
    oil_surface.gd           # Oil-specific logic
    ice_surface.gd           # Ice-specific logic
    water_surface.gd         # Water cleaning logic

resources/
  surfaces/
    oil_surface_effect.tres   # Oil effect resource
    ice_surface_effect.tres   # Ice effect resource
    water_surface_effect.tres # Water effect resource
```

## TODO List

### Phase 1: Core Infrastructure
- [ ] Create Surface base class (Node3D)
  - [ ] Add Area3D child with CircleShape3D collision
  - [ ] Surface type enum (OIL, ICE, WATER)
  - [ ] Lifetime timer (null = persistent)
  - [ ] Export radius parameter
  - [ ] overlaps_position() helper method
- [ ] Create SurfaceEffect resource
  - [ ] movement_speed_multiplier: float
  - [ ] friction_modifier: float (for future use)
  - [ ] surface_type: enum
- [ ] Add surface management to Room
  - [ ] active_surfaces: Array[Surface]
  - [ ] add_surface(surface: Surface) method
  - [ ] remove_surface(surface: Surface) method
  - [ ] get_surface_at_position(pos: Vector3) query

### Phase 2: Surface Detection
- [ ] Create SurfaceDetector component (Node)
  - [ ] Timer for periodic detection (0.1s interval)
  - [ ] Reference to parent entity
  - [ ] current_surface: Surface
  - [ ] detect_surface() method
  - [ ] surface_changed signal
- [ ] Add SurfaceDetector to Enemy
  - [ ] Connect to movement behavior
  - [ ] Apply speed multiplier from effect
- [ ] Add SurfaceDetector to Player
  - [ ] Connect to movement logic
  - [ ] Apply speed multiplier from effect

### Phase 3: Basic Surface Types
- [ ] Create OilSurface scene
  - [ ] Use puddle mesh from resources
  - [ ] Dark brown material
  - [ ] Default radius: 2.0m
  - [ ] Persistent lifetime
  - [ ] Movement multiplier: 0.5x
- [ ] Create IceSurface scene
  - [ ] Use puddle mesh (light blue material)
  - [ ] Default radius: 2.5m
  - [ ] Timed lifetime: 30s
  - [ ] Movement multiplier: 1.2x
- [ ] Create WaterSurface scene
  - [ ] Use puddle mesh (blue transparent material)
  - [ ] Default radius: 2.0m
  - [ ] Timed lifetime: 20s
  - [ ] Movement multiplier: 1.0x

### Phase 4: Oil Flask Integration
- [ ] Update OilFlask item to spawn OilSurface on break
  - [ ] Spawn surface at flask position
  - [ ] Add as child of current Room
  - [ ] Pass room reference to surface
- [ ] Test oil surface slowing enemies
- [ ] Test oil surface slowing player

### Phase 5: Water Cleaning System
- [ ] Add cleaning logic to WaterSurface
  - [ ] On spawn/ready, check overlapping surfaces
  - [ ] Instantly delete oil/ice surfaces within radius
  - [ ] Call surface.queue_free() and remove from Room array
- [ ] Test water removing oil puddles

### Phase 6: Polish & Testing
- [ ] Tune speed multipliers for feel
- [ ] Add visual feedback (particles on surface entry)
- [ ] Test multiple surfaces stacking correctly
- [ ] Verify surfaces persist when leaving/re-entering room
- [ ] Balance surface sizes and durations

## Setup Instructions

### Creating a New Surface Type

1. **Create Surface Scene**
   ```
   - Node3D (script: surface.gd)
     - MeshInstance3D (puddle mesh from resources)
     - Area3D
       - CollisionShape3D (CircleShape3D, radius: 2.0)
   ```

2. **Configure Surface Properties**
   - Set surface_type enum value
   - Assign SurfaceEffect resource
   - Set lifetime (0 = persistent, >0 = timed)
   - Adjust collision radius to match visual size

3. **Create Material**
   - StandardMaterial3D with transparency
   - Adjust albedo color for surface type
   - Enable alpha blending
   - Lower emission for darker puddles

### Spawning Surfaces from Weapons

```gdscript
# In weapon/effect script
func spawn_surface(surface_scene: PackedScene, position: Vector3):
    var room = get_tree().get_first_node_in_group("room")
    if not room:
        return

    var surface = surface_scene.instantiate()
    surface.global_position = position
    room.add_surface(surface)
```

### Testing Surfaces

1. Open `scenes/RoomTest.tscn`
2. Add OilSurface instance manually to room
3. Run scene and walk player over surface
4. Check console for "Standing on surface: OIL" debug messages
5. Verify player movement speed changes

## Technical Decisions

### Node Type: Node3D with Area3D
**Reasoning:**
- Surfaces are spatial but not physical (no RigidBody needed)
- Area3D provides spatial queries without physics simulation
- Can easily check overlaps and position containment
- Lower overhead than physics bodies

### Detection Method: Room Query with Center Point Check
**Decision: Room Query (checking entity center point)**
- Surfaces stored in Room's active_surfaces array
- Query checks if entity center (XZ) is within surface radius
- Returns surface with highest Y-position (stacking priority)
- Simple 2D distance check on XZ plane
- Entities check periodically (0.1s timer)
- Partial overlap is fine - only center point matters

**Why not physics raycast:**
- Room query is simpler (no collision layer setup)
- Same accuracy for center point detection
- Better performance with many surfaces
- Easier to debug and visualize

### Stacking Priority: Y-Position
**Reasoning:**
- Simple comparison: highest Y wins
- Predictable behavior (top surface always applies)
- Easy to debug visually
- Allows surfaces to naturally stack

### Lifetime System: Timer vs Manual
**Decision: Timer component**
- Use Timer node for consistency (matches coding patterns)
- null timer = persistent surface
- Surfaces auto-cleanup on timeout
- Room removes from active_surfaces array

### Effect Application: Speed Multiplier
**Initial approach:**
- Surfaces provide movement_speed_multiplier
- Entities apply multiplier to their base speed
- Simple and predictable
- Future: Add friction/acceleration modifiers for ice

## Integration Points

### With Weapon System
- Weapons can spawn surfaces via `spawn_surface()` helper
- Example: Oil Flask's `_on_body_entered()` creates OilSurface
- Weapon determines surface size/position

### With Enemy AI
- ChaseMovementBehaviour reads current_surface from SurfaceDetector
- Applies speed multiplier to move_speed
- Future: AI avoids hazardous surfaces (oil near fire)

### With Room System
- Room owns all surfaces as children
- Surfaces persist across room state
- Cleanup handled when room freed

### With Future Fire System
- Oil surfaces can transition to "BurningOil" surface
- Ice surfaces can melt into water
- Water surfaces extinguish fire

## Future Enhancements (Not in Initial Scope)

### Surface Interactions
- Fire + Oil = Burning Oil (damage over time)
- Fire + Ice = Melts into Water
- Electricity + Water = Electrified Water (damage + stun)
- Implement via surface transformation system

### Advanced Effects
- Poison surfaces (DoT)
- Gravity surfaces (pull/push entities)
- Teleport surfaces (portal pads)
- Bounce surfaces (launch entities)

### Visual Polish
- Particle effects on surface entry
- Splashing when surfaces created
- Surface spreading/growth animation
- Puddle ripples

### Spreading Mechanics
- Oil spreads slowly over time
- Water flows downhill
- Fire spreads across oil
- Implement via Area3D expansion + pathfinding

## Questions & Assumptions

### Assumptions Made:
1. Puddle meshes exist in resources folder (confirmed: `resources/models/Puddles/`)
2. Rooms are tagged with group "room"
3. Surfaces don't need physics (no slipping via impulses initially)
4. Player and enemies use same effect application logic
5. Detection rate of 0.1s is sufficient (10 checks/second)
6. Detection uses center point check (entity center within surface radius)
7. Water surfaces instantly delete overlapping oil/ice surfaces

### Open Questions:
1. ~~Should ice surfaces make entities "slide" with momentum, or just increase speed?~~ **RESOLVED: Just increase speed for now, add TODO for sliding**
2. ~~Should water cleaning be instant or gradual?~~ **RESOLVED: Instant deletion**
3. ~~Can surfaces overlap partially, or must they fully contain the entity?~~ **RESOLVED: Partial overlap OK, check center point only**
4. Should surfaces affect projectiles (slow arrows through oil)?
5. Max number of surfaces per room for performance?
6. Should surfaces have sound effects on entry?
