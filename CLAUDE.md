# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Bigmode 2026 Game Jam Project**: 3D action roguelike built with Godot 4.6. Short runs (15-30 min) with combat, room-based progression, improvised weapon pickups, and item-based build customization. Players dash through rooms, fight enemies, loot items, and make upgrade choices.

Key game design goals:
- 3D isometric/far third-person camera
- Movement: dash + teleport/swap/time control mechanics
- Environmental interactions: oil, water/ice, fire, electricity
- Pick-from-3 upgrades (no card system)
- Room-based progression with randomized layouts

## Running the Game

```bash
# Open in Godot Editor (main method for testing)
open -a Godot  # macOS
# Then open the project folder in Godot

# Alternative: Run via command line (if godot is in PATH)
godot --path . scenes/Game.tscn
```

The main scene is `scenes/Game.tscn`. For testing specific rooms, use `scenes/RoomTest.tscn`.

## Key Architecture Patterns

### Autoload Singletons (Global Managers)

Key autoloads defined in `project.godot`:

1. **EventBus** (`scripts/autoloads/event_bus.gd`) - Global event system for decoupled communication
2. **Settings** (`scripts/autoloads/settings_manager.gd`) - Persistent settings via INI file (`user://settings.cfg`)
3. **Audio** (`scripts/autoloads/audio_manager.gd`) - Audio playback and channel volume control
4. **MusicController** (`scripts/autoloads/music_controller.gd`) - Music state management
5. **SceneManager** (`scripts/autoloads/scene_manager.gd`) - Scene loading/transitions
6. **ItemRegistry** (`scripts/autoloads/item_registry.gd`) - Auto-discovers and caches spawnable items by category tags
7. **ShaderWarmup** (`scripts/autoloads/shader_warmup.gd`) - Precompiles particle shaders at startup to prevent frame stutters

Access these from any script:
```gdscript
Settings.get_value("audio", "music_volume", 0.5)
EventBus.level_started.emit("Room1")
var weapons = ItemRegistry.get_items_matching_any([Categories.Category.WEAPON])
```

### Component-Based Item System

Items use **behavior nodes** as child components:

- **SpawnableBehaviour** - Marks items as spawnable with category tags (rarity, type, specific)
- **PickupableBehaviour** - Enables player pickup/drop interaction
- **ThrowableBehaviour** - Physics-based throwing with velocity inheritance
- **WeaponBehaviour** (base) - Abstract weapon interface
  - **MeleeWeaponBehaviour** - Melee attack implementation with collision-based damage
  - **RangedWeaponBehaviour** - Ranged attack with projectile spawning

**Pattern**: Items are RigidBody3D with behavior nodes as children. Behaviors communicate via parent node references.

### Item Category System

Multi-tag filtering system for item spawning (`scripts/core/item_categories.gd`):

```gdscript
enum Category {
    # Rarity: COMMON, UNCOMMON, RARE, EPIC
    # Type: WEAPON, MOVEMENT, SPELL, CONSUMABLE
    # Specific: MELEE, RANGED, PROJECTILE, AREA, THROWN
}
```

Items can have multiple tags (e.g., `[WEAPON, RARE, RANGED]`). ItemRegistry filters items by category for room spawning.

### Enemy System (Strategy Pattern)

Modular enemy AI using behavior composition:

- **Enemy** (CharacterBody3D) - Base enemy with health, navigation, item drops
- **EnemyMovementBehaviour** - Abstract movement strategy
  - **ChaseMovementBehaviour** - NavMesh-based player pursuit
  - **RangedMovementBehaviour** - Keep distance while maintaining line of sight
- **EnemyAttackBehaviour** - Abstract attack strategy
  - **MeleeAttackBehaviour** - Close-range damage with cooldown
  - **RangedAttackBehaviour** - Projectile spawning with aiming

Enemies use **NavigationAgent3D** with NavMesh for pathfinding. Navigation meshes are baked at runtime by Room class.

### Room System

Room-based progression with runtime NavMesh baking:

- **Room** (base class `scripts/rooms/room.gd`) - Auto-bakes NavigationRegion3D on ready
- **RoomConnector** (`scripts/rooms/room_connector.gd`) - Bidirectional entrance/exit markers
- **ItemSpawnPoint** / **ItemThrowTarget** - Markers for item spawning with throw mechanic
- **EnemySpawner** (`scripts/spawners/enemy_spawner.gd`) - Spawns enemies at Marker3D children

**Important**: Rooms use runtime NavMesh baking. Call `room.bake_navigation()` after spawning dynamic obstacles.

### Animation System (Data-Driven)

Add `AnimationController` node to any character, assign an `AnimSet` resource — no code changes needed per character.

- `scripts/animation/animation_controller.gd` — Drives AnimationTree from character signals
- `scripts/animation/anim_set.gd` — Resource with `Dictionary[String, String]` exports
- `resources/animation/*.tres` — Per-character configs (`player_anim_set`, `basic_enemy_anim_set`)

**Flow**: Character emits signal (e.g. `started_attacking`) → AnimSet maps to action (`"attack"`) → AnimSet maps to state machine node (`"Attack"`) → Controller calls `start()` on the state machine.

**Key AnimSet fields**: `action_states` (action→state node), `signal_actions` (signal→action), `terminal_actions` (states that don't return to locomotion, e.g. death).

**Locomotion**: BlendSpace1D for player (`locomotion_blend_path`), condition-based for enemies (`to_running`/`to_idle`).

**Animation events**: AnimationPlayer Call Method tracks call `_anim_hit_frame()`, `_anim_footstep()`, `_anim_attack_window_open/close()` on the AnimationController. Melee weapons auto-connect to `hit_frame` on pickup. See `ANIMATION_EVENTS_SETUP.md`.

### Player Controller

**Player** (`scripts/player/player.gd`) - CharacterBody3D with:
- WASD movement with gravity
- Facing direction based on mouse position (XZ plane)
- Dash mechanic with Timer-based cooldown
- Item pickup/hold/throw system
- Health and damage system
- Weapon usage (melee and ranged)

Player must be in `"player"` group for enemy targeting.

## Coding Patterns & Best Practices

### Always Use Timer Nodes for Cooldowns

**Never use manual delta counting**. Use Timer nodes instead (see `CODING_PATTERNS.md`):

```gdscript
# ✅ Preferred
var _cooldown_timer: Timer

func _ready() -> void:
    _cooldown_timer = Timer.new()
    _cooldown_timer.one_shot = true
    add_child(_cooldown_timer)

func try_action():
    if _cooldown_timer.is_stopped():
        do_action()
        _cooldown_timer.start(5.0)
```

Benefits: Event-driven, no wasted CPU, easier to debug, visible in editor.

### Collision Layers (defined in project.godot)

- Layer 0: `environment` (walls, floors)
- Layer 2: `player`
- Layer 3: `item` (throwable objects)
- Layer 4: `enemy`

Use `scripts/core/collision_layers.gd` constants instead of magic numbers.

### Settings System

Use SettingsManager for persistent settings (see `SETTINGS_USAGE.md`):

```gdscript
# Auto-saves after 0.5s debounce
Settings.set_value("audio", "music_volume", 0.8)
var volume = Settings.get_value("audio", "music_volume", 0.5)
```

Stored in `user://settings.cfg` as INI format.

### Debug Console

Press `/` to open debug console. Add commands via `DebugConsole` autoload (see `DEBUG_COMMANDS.md`):

```gdscript
func _ready():
    DebugConsole.register_command("god", "Toggle invincibility")
    DebugConsole.command_entered.connect(_on_debug_command)

func _on_debug_command(cmd: String, args: PackedStringArray):
    if cmd == "god":
        invincible = !invincible
        DebugConsole.debug_log("God mode: " + str(invincible))
```

## File Structure

```
scripts/
  autoloads/        # Global singletons (EventBus, Settings, Audio, ItemRegistry, etc.)
  animation/        # AnimationController + AnimSet resource (data-driven animation system)
  player/           # Player controller
  enemies/          # Enemy AI and behavior strategies
  items/            # Item behavior components (Pickupable, Throwable, Weapon)
  rooms/            # Room management, spawning, connectors
  spawners/         # Enemy and item spawning logic
  core/             # Shared utilities (collision layers, item categories)
  ui/               # UI components
  camera/           # Camera controllers

resources/
  animation/        # AnimSet .tres resources (player_anim_set, basic_enemy_anim_set, etc.)
  models/           # Character models with AnimationPlayer + AnimationTree scenes

scenes/
  Game.tscn         # Main game scene (entry point)
  RoomTest.tscn     # Test scene for individual rooms
  Player.tscn       # Player character (has AnimationController child node)
  rooms/            # Room scenes (ExampleRoom, ExampleRoom2)
  enemies/          # Enemy scenes (Enemy, RangedEnemy) — Enemy.tscn has AnimationController
  items/            # Item scenes (Brick, Crate) with behavior components
  spawners/         # Spawner scenes (EnemySpawner)
  globals/          # Autoload scenes (DebugConsole, SettingsManager, etc.)
```

## Important Workflow Notes

### NavMesh Baking

Enemies require baked NavMeshes to move. The Room class auto-bakes on `_ready()`, but manual baking is needed in the editor for testing:

1. Open room scene (e.g., `scenes/rooms/ExampleRoom.tscn`)
2. Select `NavigationRegion3D` node
3. Click **"Bake NavMesh"** in Inspector
4. Save scene

**Runtime**: Rooms auto-bake after spawning. Call `room.rebake_navigation()` if spawning dynamic obstacles after initial load.

### Adding New Enemies

1. Duplicate `scenes/enemies/Enemy.tscn` or `scenes/enemies/RangedEnemy.tscn`
2. Attach behavior nodes: `ChaseMovementBehaviour` or `RangedMovementBehaviour`, `MeleeAttackBehaviour` or `RangedAttackBehaviour`
3. Configure exported variables (health, speed, damage, range)
4. **Set up animations** (see below)
5. Add to room via EnemySpawner or place manually in scene

See `ENEMY_SYSTEM_DESIGN.md` for full setup instructions.

### Adding Animations to a New Character

1. **Model scene**: Add `AnimationTree` with `AnimationNodeStateMachine` root. Add locomotion state (BlendSpace1D or Idle/Running) + action states (Attack, OnHit, Death, etc.). Action→locomotion transitions should use `switch_mode = AT_END`.
2. **AnimSet resource**: Duplicate `resources/animation/basic_enemy_anim_set.tres`. Set `animation_tree_path`, fill `action_states` and `signal_actions` dictionaries, set `terminal_actions`.
3. **Character scene**: Add `AnimationController` child node, assign the AnimSet. Enable `debug_logging` during development.
4. **Character script**: Just emit the signals listed in `signal_actions` (e.g. `started_attacking`, `took_damage`). The controller handles the rest.

### Adding New Items

1. Create RigidBody3D scene with mesh and collision
2. Add **SpawnableBehaviour** child node with category tags
3. Add optional behaviors: **PickupableBehaviour**, **ThrowableBehaviour**, **WeaponBehaviour**
4. Save to `scenes/items/` directory
5. ItemRegistry auto-discovers on startup

### Adding New Particle Effects

Particle effects use `GPUParticles3D` with `one_shot = true` for burst effects.

1. Create particle scene in `scenes/particles/` directory
2. Configure `ParticleProcessMaterial` for desired effect
3. **Important**: Register in `ShaderWarmup._load_particle_scenes()` to prevent frame stutters

For weapon destruction particles:
1. Create particle scene
2. Add `ParticleOnDestroyEffect` node to weapon item
3. Assign the particle scene to the effect's `particle_scene` property

Example particle scenes:
- `DestructionParticles.tscn` - Colored spheres for weapon breaking
- `TeleportParticles.tscn` - Purple spiral for teleportation

### Adding New Rooms

1. Create scene inheriting from `Room` class or use `scenes/rooms/ExampleRoom.tscn` as template
2. Add NavigationRegion3D with NavigationMesh resource
3. Add RoomConnector nodes for entrances/exits
4. Add ItemSpawnPoint and ItemThrowTarget markers for item spawning
5. Add EnemySpawner with Marker3D children for enemy spawn locations
6. Bake NavMesh in editor before testing

See `ROOMS_FEATURE_DESIGN.md` for detailed room system design.

## Design Documentation

- **GAME_DESIGN_CONTEXT.md** - High-level vision, design pillars, core mechanics
- **ENEMY_SYSTEM_DESIGN.md** - Enemy AI architecture, behavior system, setup guide
- **ROOMS_FEATURE_DESIGN.md** - Room-based progression, spawn families, item categories
- **ANIMATION_EVENTS_SETUP.md** - How to add hit frame / footstep / attack window events to animations
- **ANIMATION_TEST_GUIDE.md** - Animation system testing checklist
- **CODING_PATTERNS.md** - Established code patterns (Timer usage, etc.)
- **SETTINGS_USAGE.md** - SettingsManager API and examples
- **DEBUG_COMMANDS.md** - Debug console usage and command registration

## Godot Logs

Godot writes runtime logs to `user://logs/godot.log`. On macOS, this resolves to:

```
~/Library/Application Support/Godot/app_userdata/game-template/logs/godot.log
```

Check this file for runtime warnings and errors (invalid UIDs, missing resources, script errors, etc.). Logs rotate per session — up to 5 old files are kept alongside `godot.log`.

## Common Issues

### Enemies Not Moving

- Check if NavigationRegion3D is baked (blue/green overlay in editor)
- Verify Room has `auto_bake_navigation = true`
- Ensure enemy has NavigationAgent3D child node
- Check enemy has valid movement behavior (ChaseMovementBehaviour or RangedMovementBehaviour)

### Items Not Spawning

- Verify item has SpawnableBehaviour with category tags
- Check ItemRegistry console output on startup for registration errors
- Ensure item scene is in `scenes/items/` directory

### Player Not Picking Up Items

- Check item has PickupableBehaviour component
- Verify `pickup_range` on Player (default 2.0m)
- Ensure item is on collision layer 3 (`item`)

### Projectiles Not Working

- Verify RangedWeaponBehaviour has `projectile_scene` assigned
- Check projectile scene has collision shape and RigidBody3D
- Ensure projectile uses correct collision layers/masks

### Animations Not Working

- Check `AnimationController` has an `AnimSet` assigned, and `animation_tree_path` matches the actual AnimationTree path
- Check `action_states` node names match the AnimationTree state machine (case-sensitive)
- Enable `debug_logging` on AnimationController for console diagnostics
- Actions feel delayed? Check `xfade_time` on transitions. Controller uses `start()` (immediate) for actions, `travel()` only for returning to locomotion
- Weapon hit frames not firing? AnimationPlayer needs a Call Method track targeting `../../AnimationController` with `_anim_hit_frame()`. See `ANIMATION_EVENTS_SETUP.md`

### Particle Effects Causing Frame Stutters

When new particle effects are first used, Godot compiles their shaders on-demand, causing frame hitches.

**Solution**: Register particle scenes in `ShaderWarmup` autoload:

```gdscript
# In scripts/autoloads/shader_warmup.gd, add to _load_particle_scenes():
_try_load("res://scenes/particles/YourNewParticles.tscn")
```

The warmup system spawns particles off-screen at startup to force shader compilation before gameplay.
