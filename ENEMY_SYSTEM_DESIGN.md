# Enemy System Design

## Overview
Implement a modular enemy system using the Strategy pattern for movement and attack behaviors. Enemies navigate using NavMesh and can spawn from designated points or be dropped from above.

## Architecture

### Core Components

1. **Enemy (Base)**
   - RigidBody3D or CharacterBody3D (TBD based on physics needs)
   - Health system with damage/death
   - References to behavior components
   - Item drop system on death
   - Collision layers: enemy layer (4)

2. **EnemyMovementBehaviour (Base Class)**
   - Abstract interface for movement strategies
   - `update_movement(delta: float, enemy: Node3D, target: Vector3) -> Vector3`
   - Access to NavigationAgent3D

3. **EnemyAttackBehaviour (Base Class)**
   - Abstract interface for attack strategies
   - `can_attack(enemy: Node3D, target: Node3D) -> bool`
   - `execute_attack(enemy: Node3D, target: Node3D) -> void`
   - `get_attack_range() -> float`

4. **NavigationAgent3D**
   - Attached to each enemy
   - Handles pathfinding via NavMesh
   - Built-in avoidance for enemy-enemy collision

5. **EnemySpawner**
   - Manages spawn points (doors, gates, markers)
   - Handles drop spawning (random positions from above)
   - Configurable spawn waves/timing

### Initial Implementations

#### ChaseMovementBehaviour
- Pursues player directly using NavMesh
- Configurable speed
- Stops when within attack range
- Idles when player is too far (configurable max chase distance)

#### MeleeAttackBehaviour
- Close-range melee attack
- Cooldown between attacks
- Damage value
- Attack range (e.g., 1.5m)
- Attack animation trigger (future)

### Room Integration

Each room will have:
- **NavigationRegion3D** with baked NavMesh
- **EnemySpawner** node(s) with child spawn point markers
- **Surface colliders** (future) for behavior modification

## TODO List

### Phase 1: Core Structure ✅ COMPLETE
- [x] Create base Enemy scene and script (CharacterBody3D)
  - [x] Health system (HP, take_damage(), die())
  - [x] Reference to player node
  - [x] Placeholder visual (capsule mesh in red/orange)
  - [x] Collision shape and layers
- [x] Create EnemyMovementBehaviour base class
  - [x] Abstract methods for interface
  - [x] Reference to NavigationAgent3D
- [x] Create EnemyAttackBehaviour base class
  - [x] Abstract methods for interface
  - [x] Cooldown timer system
- [x] Add health/damage system to Player

### Phase 2: Navigation ⚠️ NEEDS MANUAL STEP
- [x] Add NavigationRegion3D to ExampleRoom
  - [ ] **USER ACTION REQUIRED:** Bake NavMesh in Godot Editor (see instructions below)
- [x] Add NavigationAgent3D to Enemy
  - [x] Configure avoidance
  - [x] Set up target position updates

### Phase 3: Basic Behaviors ✅ COMPLETE
- [x] Implement ChaseMovementBehaviour
  - [x] Follow player using nav agent
  - [x] Stop at attack range
  - [x] Idle when too far
  - [x] Export variables: speed, max_chase_distance
- [x] Implement MeleeAttackBehaviour
  - [x] Check if in range
  - [x] Execute attack with cooldown
  - [x] Apply damage to player
  - [x] Export variables: damage, attack_range, cooldown

### Phase 4: Enemy Integration ✅ COMPLETE
- [x] Wire behaviors to Enemy script
  - [x] Call movement behavior in _physics_process
  - [x] Call attack behavior check/execute
  - [x] Update NavigationAgent target each frame
- [x] Test single enemy added to ExampleRoom (TestEnemy node)

### Phase 5: Spawning System ✅ COMPLETE
- [x] Create EnemySpawner scene and script
  - [x] Collect child Marker3D nodes as spawn points
  - [x] spawn_at_point(point_index: int, enemy_scene: PackedScene)
  - [x] spawn_at_random_point(enemy_scene: PackedScene)
  - [x] spawn_dropped(enemy_scene: PackedScene) - random position from above
- [ ] Add EnemySpawner to ExampleRoom (optional - can be added per room)
  - [ ] Add spawn point markers (doors, corners)
  - [ ] Test spawning enemies at runtime

### Phase 6: Item Drops ✅ COMPLETE
- [x] Add drop system to Enemy
  - [x] Array of droppable item scenes
  - [x] spawn_drops() on death
  - [x] Random drop chance
  - [x] Spawn at enemy position

### Phase 7: Testing & Polish 🔄 IN PROGRESS
- [ ] Test with multiple enemies
- [ ] Tune NavMesh avoidance parameters
- [ ] Verify enemy-player collision
- [ ] Verify enemy-item collision (can they kick items?)
- [ ] Balance health/damage/speed values

---

## Setup Instructions

### Baking the NavMesh (Required for enemies to move!)

1. Open `scenes/rooms/ExampleRoom.tscn` in Godot
2. Select the `NavigationRegion3D` node
3. In the Inspector, click the `Bake NavMesh` button
4. The walkable floor area should now be highlighted in blue/green
5. Save the scene

**Note:** You need to rebake the NavMesh whenever you modify the room geometry (walls, floors, obstacles).

### Testing the Enemy System

1. **Ensure NavMesh is baked** (see above)
2. Open and run `scenes/Game.tscn` or `scenes/RoomTest.tscn`
3. The TestEnemy in ExampleRoom should:
   - Chase the player
   - Stop when in melee range (1.5m)
   - Attack every 1.5 seconds for 10 damage
4. Check the console for "Player took X damage" messages

### Adding More Enemies

**Option 1: Place manually in scene**
- Drag `scenes/enemies/Enemy.tscn` into your room scene
- Position as desired

**Option 2: Use EnemySpawner**
```gdscript
# Add EnemySpawner to room
var spawner = preload("res://scenes/spawners/EnemySpawner.tscn").instantiate()
add_child(spawner)

# Add spawn point markers as children
var marker = Marker3D.new()
marker.position = Vector3(5, 0, 5)
spawner.add_child(marker)

# Spawn enemy at point
var enemy_scene = preload("res://scenes/enemies/Enemy.tscn")
spawner.spawn_at_point(0, enemy_scene)

# Or spawn dropped from above
spawner.spawn_dropped(enemy_scene)
```

### Configuring Enemy Stats

Select an Enemy instance in the scene tree and modify in Inspector:
- **max_health**: Enemy HP (default: 100)
- **drop_items**: Array of PackedScenes to drop on death
- **drop_chance**: Probability of dropping item (0.0-1.0, default: 0.5)
- **ChaseMovementBehaviour**:
  - move_speed: How fast enemy moves (default: 3.5)
  - max_chase_distance: Stop chasing beyond this distance (default: 30)
- **MeleeAttackBehaviour**:
  - damage: Damage per hit (default: 10)
  - attack_range: Distance to attack from (default: 1.5)
  - attack_cooldown: Seconds between attacks (default: 1.5)

## Future Enhancements (Not in Initial Scope)

### Surface Interactions
- Oil surfaces slow movement
- Ice surfaces freeze enemies
- Implement via Area3D collision detection
- Modify behavior parameters dynamically

### Enchantment System
- Spawner assigns buffs/debuffs to enemies
- Examples: faster, tougher, explosive on death
- Modifies base stats or adds new behaviors

### Additional Behaviors
- **Movement**: Patrol, Flee, Circle Strafe, Teleport
- **Attack**: Ranged, AoE, Charge, Grab

## Technical Decisions

### CharacterBody3D vs RigidBody3D
**Decision: CharacterBody3D**
- Better integration with NavigationAgent3D
- More predictable movement for AI
- Less physics complexity
- Player is likely CharacterBody3D, consistent

### Behavior Assignment
- Behaviors attached as child nodes of Enemy
- Enemy script finds behaviors via get_node() or get_children()
- Alternative: Export variables to assign behavior scripts (less flexible)

### Player Detection
- No detection system needed (enemies always aware)
- Enemy directly references player node via get_tree().get_first_node_in_group("player")
- Player must be in "player" group

## File Structure

```
scenes/
  enemies/
    Enemy.tscn           # Base enemy scene
    SimpleEnemy.tscn     # Melee enemy variant
  spawners/
    EnemySpawner.tscn    # Spawner manager

scripts/
  enemies/
    enemy.gd                      # Base enemy logic
    enemy_movement_behaviour.gd   # Abstract base
    enemy_attack_behaviour.gd     # Abstract base
    chase_movement_behaviour.gd   # Implementation
    melee_attack_behaviour.gd     # Implementation
  spawners/
    enemy_spawner.gd              # Spawn management
```

## Questions & Assumptions

### Assumptions Made:
1. Player scene is tagged with group "player"
2. Enemies use CharacterBody3D for physics
3. NavMesh covers walkable floor areas
4. Initial implementation: one melee enemy type
5. Enemies can interact with items (kick them)
6. Damage numbers/feedback handled separately (future)

### Open Questions:
1. Should enemies have different sizes/scales?
2. Do we need enemy-specific animations now or placeholder only?
3. Should spawner handle waves/timing or just spawn on demand?
4. Max number of enemies per room?
