# Surface System - Implementation Complete

## What Was Implemented

### Core System (Phase 1-2)

1. **SurfaceEffect Resource** (`scripts/surfaces/surface_effect.gd`)
   - Data container for surface properties
   - Three types: OIL, ICE, WATER
   - Movement speed multipliers and friction modifiers

2. **Surface Base Class** (`scripts/surfaces/surface.gd`)
   - Node3D with configurable radius
   - Lifetime system (persistent or timed)
   - Auto-registers with Room
   - Stacking support via Y-position priority

3. **Room Integration** (updated `scripts/rooms/room.gd`)
   - `active_surfaces` array tracking
   - `add_surface()` / `remove_surface()` methods
   - `get_top_surface_at_position()` - center point detection with variable radius
   - `get_surfaces_in_radius()` - for overlap queries

4. **SurfaceDetector Component** (`scripts/surfaces/surface_detector.gd`)
   - Attaches to entities (Player/Enemy)
   - Timer-based detection (0.1s intervals)
   - `get_speed_multiplier()` helper method
   - Emits `surface_changed` signal

### Surface Types (Phase 3)

5. **OilSurface** (`scripts/surfaces/oil_surface.gd`)
   - 0.5x speed multiplier (sticky/slow)
   - Radius: 2.0m
   - Persistent lifetime

6. **IceSurface** (`scripts/surfaces/ice_surface.gd`)
   - 1.2x speed multiplier (fast/slippery)
   - Radius: 2.5m
   - Lifetime: 30 seconds
   - TODO: Add sliding momentum

7. **WaterSurface** (`scripts/surfaces/water_surface.gd`)
   - 1.0x speed multiplier (neutral)
   - Radius: 2.0m
   - Lifetime: 20 seconds
   - Instantly cleans overlapping oil/ice surfaces

### Entity Integration (Phase 2)

8. **Player Movement** (updated `scripts/player/player.gd`)
   - Caches SurfaceDetector component
   - Applies speed multiplier to movement

9. **Enemy Movement** (updated `scripts/enemies/chase_movement_behaviour.gd` and `ranged_movement_behaviour.gd`)
   - Queries SurfaceDetector from enemy parent
   - Applies speed multiplier to navigation movement

### Weapon Effect (Phase 4)

10. **SpawnSurfaceEffect** (`scripts/items/effects/spawn_surface_effect.gd`)
    - OnDestroyEffect component
    - Spawns configurable surface scene when weapon breaks
    - Ready for OilFlask integration

## What Needs to Be Done in Godot Editor

### 1. Create Surface Scenes

You need to create three surface scene files:

**scenes/surfaces/OilSurface.tscn:**
```
OilSurface (Node3D) - Script: res://scripts/surfaces/oil_surface.gd
└── MeshInstance3D (puddle mesh, dark brown material)
```

**scenes/surfaces/IceSurface.tscn:**
```
IceSurface (Node3D) - Script: res://scripts/surfaces/ice_surface.gd
└── MeshInstance3D (puddle mesh, light blue material)
```

**scenes/surfaces/WaterSurface.tscn:**
```
WaterSurface (Node3D) - Script: res://scripts/surfaces/water_surface.gd
└── MeshInstance3D (puddle mesh, blue transparent material)
```

**Steps:**
1. Create new scene (Node3D)
2. Attach appropriate script (oil_surface.gd, ice_surface.gd, or water_surface.gd)
3. Add MeshInstance3D child
4. In MeshInstance3D Inspector:
   - Mesh: Load `res://resources/models/Puddles/puddles.fbx` (or .blend)
   - Create new StandardMaterial3D
   - Set albedo color (brown for oil, light blue for ice, blue for water)
   - Enable transparency if needed (water)
5. Export variables will use defaults from script
6. Save to `scenes/surfaces/`

### 2. Add SurfaceDetector to Player

1. Open `scenes/Player.tscn`
2. Add child node (type: Node)
3. Attach script: `res://scripts/surfaces/surface_detector.gd`
4. Name it: `SurfaceDetector`
5. Optional: Enable `debug_print` in Inspector to see surface changes in console
6. Save

### 3. Add SurfaceDetector to Enemy Scenes

For **each** enemy scene:
1. Open `scenes/enemies/Enemy.tscn` (and any variants)
2. Add child node (type: Node)
3. Attach script: `res://scripts/surfaces/surface_detector.gd`
4. Name it: `SurfaceDetector`
5. Save

Repeat for:
- `scenes/enemies/RangedEnemy.tscn` (if exists)
- Any other enemy variants

### 4. Update OilFlask Scene

1. Open `scenes/items/OilFlask.tscn`
2. Add child node (type: Node)
3. Attach script: `res://scripts/items/effects/spawn_surface_effect.gd`
4. Name it: `SpawnSurfaceEffect`
5. In Inspector, set properties:
   - `surface_scene`: Load `res://scenes/surfaces/OilSurface.tscn`
   - `spawn_offset`: Vector3(0, 0.05, 0)
6. Ensure OilFlask has `WeaponBehaviour` with `max_durability: 1`
7. Save

## Testing Checklist

### Test 1: Manual Surface Spawn
1. Open `scenes/RoomTest.tscn`
2. Add OilSurface instance to room (position Y: 0.05)
3. Run scene
4. Walk player over oil surface
5. Check console: Should see "Room: Added surface" message
6. Verify player moves slower (speed reduced by ~50%)

### Test 2: Oil Flask
1. Open `scenes/RoomTest.tscn`
2. Add OilFlask instance to room
3. Run scene
4. Pick up flask (E key)
5. Throw flask (right-click)
6. Flask should break on impact
7. Oil surface should spawn at break location
8. Walk over surface - should slow movement

### Test 3: Surface Stacking
1. Manually add OilSurface (Y: 0.05) to room
2. Manually add IceSurface (Y: 0.10) at same XZ position
3. Run scene
4. Walk over stacked surfaces
5. Should feel ICE effect (faster), not oil
6. Check console: Should report Ice surface (higher Y wins)

### Test 4: Water Cleaning
1. Add OilSurface to room (position: 0, 0.05, 0)
2. Add WaterSurface overlapping it (position: 0, 0.06, 0)
3. Run scene
4. Water should instantly delete the oil surface
5. Check console: "Water surface cleaning OilSurface"

### Test 5: Enemy Movement
1. Add OilSurface to room
2. Add Enemy to room
3. Run scene
4. Lure enemy onto oil surface
5. Enemy should move slower on oil

### Test 6: Surface Lifetimes
1. Add IceSurface to room
2. Run scene
3. Wait 30 seconds
4. Ice surface should disappear (queue_free)
5. Check console: "Room: Removed surface"

## Expected Behavior

### Oil Surface
- Entities move at 50% speed
- Dark brown puddle visual
- Persists until cleaned by water
- Spawned by OilFlask destruction

### Ice Surface
- Entities move at 120% speed
- Light blue puddle visual
- Lasts 30 seconds then disappears
- TODO: Add sliding/reduced control

### Water Surface
- Entities move at normal speed (100%)
- Blue transparent puddle visual
- Lasts 20 seconds then disappears
- Instantly removes overlapping oil/ice

## Known Limitations

1. **No scene files yet** - Surfaces need to be created in editor with puddle meshes
2. **No visual effects** - No particles on surface entry/exit (future enhancement)
3. **Ice sliding not implemented** - Currently just speed boost (marked as TODO)
4. **Center point only** - Detection checks entity center, not full footprint
5. **No sound effects** - Silent surface interactions (future enhancement)

## Next Steps (Future Enhancements)

1. Create ice/water flask items with spawn surface effects
2. Add particle effects on surface entry
3. Implement ice sliding momentum mechanics
4. Add surface interactions (fire + oil = burning oil)
5. Visual feedback (ripples, footprints, splashes)
6. Sound effects (splash, freeze, sizzle)
7. Surface spreading mechanics (oil flows, water spreads)

## File Manifest

### Scripts Created
- `scripts/surfaces/surface_effect.gd` ✓
- `scripts/surfaces/surface.gd` ✓
- `scripts/surfaces/surface_detector.gd` ✓
- `scripts/surfaces/oil_surface.gd` ✓
- `scripts/surfaces/ice_surface.gd` ✓
- `scripts/surfaces/water_surface.gd` ✓
- `scripts/items/effects/spawn_surface_effect.gd` ✓

### Scripts Modified
- `scripts/rooms/room.gd` ✓ (added surface management)
- `scripts/player/player.gd` ✓ (added surface detection)
- `scripts/enemies/chase_movement_behaviour.gd` ✓ (added surface effects)
- `scripts/enemies/ranged_movement_behaviour.gd` ✓ (added surface effects)

### Scenes To Create (In Editor)
- `scenes/surfaces/OilSurface.tscn` ⚠️
- `scenes/surfaces/IceSurface.tscn` ⚠️
- `scenes/surfaces/WaterSurface.tscn` ⚠️

### Scenes To Modify (In Editor)
- `scenes/Player.tscn` ⚠️ (add SurfaceDetector)
- `scenes/enemies/Enemy.tscn` ⚠️ (add SurfaceDetector)
- `scenes/items/OilFlask.tscn` ⚠️ (add SpawnSurfaceEffect)

## Variable Radius Support

The system fully supports variable surface radii:

- Each surface has `@export var radius: float = 2.0` 
- Can be overridden per-instance in Godot editor
- Room query checks: `distance <= surface.radius`
- Works for all surface types (oil, ice, water)
- Example: Create small oil puddle (radius: 1.0) or large one (radius: 5.0)

## Architecture Notes

- **No collision layers needed** - Uses pure distance math (Vector2 XZ check)
- **Timer-based detection** - Entities check every 0.1s, not every frame
- **Room ownership** - Surfaces are children of Room for persistence
- **Effect composition** - SpawnSurfaceEffect is reusable for any flask/grenade
- **Simple stacking** - Highest Y position wins, predictable behavior
