# Player Upgrade System — design doc

*Feature design for player upgrades (roguelike build customization). Iterate here as we implement.*

---

## Goals

- Players collect **upgrades** during a run that modify their abilities and weapons.
- Two upgrade types:
  1. **Trigger upgrades**: React to game events (enemy kill, weapon break, dash used, etc.) and execute effects (heal, spawn surface, throw item from crowd, etc.).
  2. **Stat modifier upgrades**: Permanently modify weapon stats (durability, damage, range) or player abilities (dash distance, cooldown).
- Game designers can create new upgrades easily using the editor (scene-based, similar to items).
- Upgrades **stack** — the same upgrade can be acquired multiple times with cumulative effect.
- Weapon modifiers apply to **future spawned weapons only** (not currently held).

---

## Architecture overview

```
┌──────────────────────────────────────────────────────────────────┐
│                        UpgradeManager                            │
│  (Autoload singleton - tracks acquired upgrades, listens for     │
│   global events, applies weapon modifiers to new weapons)        │
└─────────────────┬────────────────────────────────────────────────┘
                  │
    ┌─────────────┼─────────────────────┐
    │             │                     │
    ▼             ▼                     ▼
┌────────┐  ┌──────────┐  ┌───────────────────────┐
│EventBus│  │ Player   │  │ ItemRegistry          │
│(signals)│ │(abilities)│ │(weapon spawn hook)    │
└────────┘  └──────────┘  └───────────────────────┘
```

### Key components

1. **UpgradeManager** (autoload) — Central manager that:
   - Tracks all acquired upgrades (dictionary of upgrade_id → count)
   - Connects to EventBus for global triggers (enemy_killed, weapon_thrown, etc.)
   - Executes trigger-based upgrade effects when events fire
   - Provides `apply_weapon_modifiers(weapon)` for stat modifiers
   - Exposes API for granting/removing upgrades (for console commands, UI, chests)

2. **UpgradeRegistry** (autoload) — Auto-discovers upgrade scenes in `res://scenes/upgrades/`:
   - Mirrors ItemRegistry pattern
   - Builds category cache for filtering (by type, rarity, tags)
   - Provides `get_random_upgrades(count, filter)` for pick-from-3 UI

3. **EventBus extensions** — New signals for upgrade triggers:
   - `enemy_killed(enemy: Enemy, killer: Node3D)` — when enemy dies
   - `enemy_spawned(enemy: Enemy)` — when enemy spawns in room
   - `weapon_thrown(weapon: Node3D, direction: Vector3, from_crowd: bool)`
   - `weapon_broken(weapon: Node3D)` — when weapon durability reaches 0
   - `weapon_spawned(weapon: Node3D)` — when weapon enters world (spawn or crowd throw)
   - `crowd_throw_requested()` — when crowd should throw an item
   - `player_dashed(direction: Vector3)` — when player dashes a
   - `player_teleported(from: Vector3, to: Vector3)` — when player teleports
   - `item_picked_up(item: Node3D, picker: Node3D)` — when item picked up

4. **Upgrade base classes** — Scene components attached to upgrade scenes:
   - `BaseUpgrade` — Metadata (name, description, icon, tags)
   - `TriggerUpgrade` — Listens for specific event, has chance/cooldown, executes child effects
   - `WeaponModifierUpgrade` — Defines stat modifications for weapons matching filter

---

## Upgrade scene structure

Upgrades are scenes in `res://scenes/upgrades/` with this structure:

```
UpgradeName.tscn
├── BaseUpgrade (root node with metadata)
│   ├── @export var upgrade_name: String
│   ├── @export var description: String
│   ├── @export var icon: Texture2D
│   ├── @export var tags: Array[UpgradeCategory]
│   └── @export var max_stacks: int = -1  # -1 = unlimited
│
├── TriggerUpgrade (optional - for event-driven upgrades)
│   ├── @export var trigger: UpgradeTrigger.Type  # enum
│   ├── @export var chance: float = 1.0  # 0-1 probability
│   ├── @export var cooldown: float = 0.0  # seconds between activations
│   └── Child effect nodes...
│
└── WeaponModifierUpgrade (optional - for stat modifiers)
    ├── @export var weapon_filter: Array[Categories.Category]
    ├── @export var stat_modifiers: Array[StatModifier]
    └── (StatModifier: property name, delta value, multiply vs add)
```

---

## Trigger types (UpgradeTrigger.Type enum)

```gdscript
enum Type {
    # Combat triggers
    ENEMY_KILLED,           # Any enemy killed
    ENEMY_SPAWNED,          # Enemy appears in room
    DAMAGE_DEALT,           # Player deals damage
    DAMAGE_TAKEN,           # Player takes damage

    # Weapon triggers
    WEAPON_THROWN,          # Player throws a weapon
    WEAPON_BROKEN,          # Weapon durability reaches 0
    WEAPON_ATTACK,          # Weapon attacks (melee swing, ranged shot)
    CROWD_THROW,            # Crowd throws an item

    # Movement triggers
    PLAYER_DASHED,          # Player uses dash
    PLAYER_TELEPORTED,      # Player uses teleport

    # Item triggers
    ITEM_PICKED_UP,         # Player picks up any item
    ITEM_DROPPED,           # Player drops an item

    # Room triggers
    ROOM_ENTERED,           # Player enters new room
    ROOM_CLEARED,           # All enemies in room defeated
}
```

---

## Effect types for trigger upgrades

Trigger upgrades execute **child effect nodes** when activated. These extend existing effect system:

### New effect base classes

```gdscript
# scripts/upgrades/effects/upgrade_effect.gd
class_name UpgradeEffect extends Node

## Base class for upgrade effects
## Receives trigger context (enemy, weapon, position, etc.)

func execute(context: Dictionary) -> void:
    push_warning("UpgradeEffect.execute() not implemented")
```

### Built-in upgrade effects

| Effect class | Description | Context used |
|--------------|-------------|--------------|
| `HealPlayerEffect` | Heal player by flat or % amount | — |
| `DamageAreaEffect` | Deal damage to enemies in radius | `position` |
| `SpawnSurfaceUpgradeEffect` | Spawn oil/ice/water at position | `position` |
| `SpawnProjectileEffect` | Fire projectile at nearest enemy | `position`, `direction` |
| `RepairWeaponEffect` | Restore durability to held weapon | — |
| `CrowdThrowEffect` | Make crowd throw an item | `item_filter` |
| `SpawnItemEffect` | Spawn specific item at position | `position` |
| `ModifyStatTemporaryEffect` | Temporary stat buff | `duration` |
| `ExplodeEffect` | Spawn explosion at position | `position` |

---

## Weapon modifier system

`WeaponModifierUpgrade` defines stat changes applied to weapons matching a filter.

### StatModifier resource

```gdscript
# scripts/upgrades/stat_modifier.gd
class_name StatModifier extends Resource

enum Operation { ADD, MULTIPLY }
enum Stat {
    DAMAGE,
    DURABILITY,
    MAX_DURABILITY,
    ATTACK_COOLDOWN,
    SWING_RANGE,      # Melee only
    SWING_ANGLE,      # Melee only
    KNOCKBACK_FORCE,  # Melee only
    PROJECTILE_SPEED, # Ranged only
    SPREAD,           # Ranged only
    MAX_AMMO,         # Ranged only
}

@export var stat: Stat
@export var operation: Operation = Operation.ADD
@export var value: float = 0.0
```

### Application flow

1. When weapon spawns, emit `EventBus.weapon_spawned(weapon)`
2. UpgradeManager receives signal, calls `apply_weapon_modifiers(weapon)`
3. For each acquired `WeaponModifierUpgrade`:
   - Check if weapon matches `weapon_filter` (via SpawnableBehaviour tags)
   - Apply each `StatModifier` to weapon's `WeaponBehaviour` properties
   - Multiply by upgrade stack count

```gdscript
# In UpgradeManager
func apply_weapon_modifiers(weapon: Node3D) -> void:
    var spawnable = weapon.get_node_or_null("SpawnableBehaviour")
    if not spawnable:
        return

    var weapon_behaviour = weapon.get_node_or_null("WeaponBehaviour")
    # Also check for MeleeWeaponBehaviour, RangedWeaponBehaviour

    for upgrade_id in _acquired_upgrades:
        var upgrade_scene = UpgradeRegistry.get_upgrade(upgrade_id)
        var modifier = _get_weapon_modifier(upgrade_scene)
        if not modifier:
            continue

        # Check filter match
        if not spawnable.has_any_category(modifier.weapon_filter):
            continue

        # Apply modifiers × stack count
        var stacks = _acquired_upgrades[upgrade_id]
        for stat_mod in modifier.stat_modifiers:
            _apply_stat_modifier(weapon_behaviour, stat_mod, stacks)
```

---

## UpgradeManager API

```gdscript
# scripts/autoloads/upgrade_manager.gd
extends Node

signal upgrade_acquired(upgrade_id: String, new_count: int)
signal upgrade_removed(upgrade_id: String, new_count: int)
signal upgrade_triggered(upgrade_id: String, trigger_type: UpgradeTrigger.Type)

## Grant an upgrade to the player (stacks if already owned)
func grant_upgrade(upgrade_id: String, count: int = 1) -> void

## Remove upgrade stacks (returns actual amount removed)
func remove_upgrade(upgrade_id: String, count: int = 1) -> int

## Get current stack count for upgrade
func get_upgrade_count(upgrade_id: String) -> int

## Check if player has upgrade
func has_upgrade(upgrade_id: String) -> bool

## Get all acquired upgrades as Dictionary[upgrade_id, count]
func get_all_upgrades() -> Dictionary

## Clear all upgrades (for new run)
func reset_upgrades() -> void

## Apply weapon stat modifiers to a newly spawned weapon
func apply_weapon_modifiers(weapon: Node3D) -> void
```

---

## UpgradeRegistry API

```gdscript
# scripts/autoloads/upgrade_registry.gd
extends Node

## Get upgrade scene by ID (filename without extension)
func get_upgrade(upgrade_id: String) -> PackedScene

## Get all registered upgrade IDs
func get_all_upgrade_ids() -> Array[String]

## Get random upgrades matching filter (for pick-from-3)
func get_random_upgrades(count: int, filter: Array[UpgradeCategory] = []) -> Array[String]

## Get upgrades matching all specified categories
func get_upgrades_matching_all(categories: Array[UpgradeCategory]) -> Array[String]

## Get upgrades matching any specified category
func get_upgrades_matching_any(categories: Array[UpgradeCategory]) -> Array[String]
```

---

## Upgrade categories (UpgradeCategory enum)

```gdscript
# scripts/core/upgrade_categories.gd
class_name UpgradeCategories

enum Category {
    # Rarity
    COMMON = 0,
    UNCOMMON = 1,
    RARE = 2,
    EPIC = 3,

    # Type
    TRIGGER = 10,      # Event-driven effect
    WEAPON_MOD = 11,   # Weapon stat modifier
    ABILITY_MOD = 12,  # Player ability modifier

    # Trigger subtypes
    ON_KILL = 20,
    ON_DAMAGE = 21,
    ON_THROW = 22,
    ON_MOVEMENT = 23,

    # Weapon subtypes
    AFFECTS_MELEE = 30,
    AFFECTS_RANGED = 31,
    AFFECTS_ALL_WEAPONS = 32,
}
```

---

## Debug console commands

For testing upgrades before UI is implemented:

```
/upgrade list              — List all registered upgrades
/upgrade grant <id>        — Grant upgrade to player
/upgrade grant <id> <n>    — Grant n stacks of upgrade
/upgrade remove <id>       — Remove one stack of upgrade
/upgrade clear             — Remove all upgrades
/upgrade status            — Show all acquired upgrades with counts
```

---

## Integration with existing systems

### ItemRegistry / weapon spawning

Modify weapon spawn flow to apply upgrades:

```gdscript
# In room spawn logic or ItemSpawnPoint
func _spawn_item(item_scene: PackedScene) -> Node3D:
    var item = item_scene.instantiate()
    _room.add_child(item)

    # Notify UpgradeManager to apply modifiers
    EventBus.weapon_spawned.emit(item)

    return item
```

### EventBus signal emissions

Add signal emissions to existing code:

| Location | Signal to emit |
|----------|----------------|
| `Enemy.die()` | `EventBus.enemy_killed.emit(self, killer)` |
| `EnemySpawner._spawn_enemy()` | `EventBus.enemy_spawned.emit(enemy)` |
| `ThrowableBehaviour.throw()` | `EventBus.weapon_thrown.emit(item, direction, from_crowd)` |
| `WeaponBehaviour.destroy()` | `EventBus.weapon_broken.emit(item)` |
| `DashComponent.activate()` | `EventBus.player_dashed.emit(direction)` |
| `TeleportComponent.execute_teleport()` | `EventBus.player_teleported.emit(from, to)` |
| `PickupableBehaviour.try_pick_up()` | `EventBus.item_picked_up.emit(item, picker)` |

### Player ability modifiers

For upgrades like "+1 dash charge" or "+1m teleport range":

```gdscript
# In UpgradeManager
func _apply_ability_modifier(upgrade: Node) -> void:
    var player = get_tree().get_first_node_in_group("player")
    if not player:
        return

    # Example: dash charge upgrade
    var dash = player.get_node_or_null("DashComponent")
    if dash and upgrade.affects_dash:
        dash.add_charge()  # Already implemented!
```

---

## Example upgrades

### 1. Heal on Kill (Trigger upgrade)

```
HealOnKill.tscn
├── BaseUpgrade
│   ├── upgrade_name = "Vampiric Strike"
│   ├── description = "10% chance to heal 5 HP when killing an enemy"
│   └── tags = [COMMON, TRIGGER, ON_KILL]
│
└── TriggerUpgrade
    ├── trigger = ENEMY_KILLED
    ├── chance = 0.1
    ├── cooldown = 0.0
    │
    └── HealPlayerEffect
        └── heal_amount = 5.0
```

### 2. Melee Durability+ (Weapon modifier)

```
MeleeDurability.tscn
├── BaseUpgrade
│   ├── upgrade_name = "Sturdy Grip"
│   ├── description = "Melee weapons have +5 durability"
│   └── tags = [COMMON, WEAPON_MOD, AFFECTS_MELEE]
│
└── WeaponModifierUpgrade
    ├── weapon_filter = [Categories.MELEE]
    └── stat_modifiers = [
            StatModifier(MAX_DURABILITY, ADD, 5.0),
            StatModifier(DURABILITY, ADD, 5.0)  # Start with bonus
        ]
```

### 3. Ice Teleport (Trigger upgrade)

```
IceTeleport.tscn
├── BaseUpgrade
│   ├── upgrade_name = "Frostblink"
│   ├── description = "Leave an ice surface when you teleport"
│   └── tags = [UNCOMMON, TRIGGER, ON_MOVEMENT]
│
└── TriggerUpgrade
    ├── trigger = PLAYER_TELEPORTED
    ├── chance = 1.0
    ├── cooldown = 0.0
    │
    └── SpawnSurfaceUpgradeEffect
        ├── surface_scene = preload("res://scenes/surfaces/IceSurface.tscn")
        └── use_context_position = true  # Spawn at teleport origin
```

### 4. Crossbow Damage+ (Weapon modifier)

```
CrossbowDamage.tscn
├── BaseUpgrade
│   ├── upgrade_name = "Sharpened Bolts"
│   ├── description = "Crossbows deal +3 damage"
│   └── tags = [UNCOMMON, WEAPON_MOD, AFFECTS_RANGED]
│
└── WeaponModifierUpgrade
    ├── weapon_filter = [Categories.CROSSBOW]  # Specific item tag
    └── stat_modifiers = [
            StatModifier(DAMAGE, ADD, 3.0)
        ]
```

### 5. Crowd Throws on Break (Trigger upgrade)

```
CrowdThrowOnBreak.tscn
├── BaseUpgrade
│   ├── upgrade_name = "Encore"
│   ├── description = "When a weapon breaks, 50% chance the crowd throws a new one"
│   └── tags = [RARE, TRIGGER, ON_THROW]
│
└── TriggerUpgrade
    ├── trigger = WEAPON_BROKEN
    ├── chance = 0.5
    ├── cooldown = 1.0  # Prevent spam
    │
    └── CrowdThrowEffect
        └── item_filter = [Categories.WEAPON]
```

---

## Implementation order

### Phase 1: Core infrastructure ✅
1. [x] Create `UpgradeCategories` enum (`scripts/core/upgrade_categories.gd`)
2. [x] Create `StatModifier` resource (`scripts/upgrades/stat_modifier.gd`)
3. [x] Create `BaseUpgrade` script (`scripts/upgrades/base_upgrade.gd`)
4. [x] Create `UpgradeTrigger` enum and script (`scripts/upgrades/upgrade_trigger.gd`)
5. [x] Create `TriggerUpgrade` script (`scripts/upgrades/trigger_upgrade.gd`)
6. [x] Create `WeaponModifierUpgrade` script (`scripts/upgrades/weapon_modifier_upgrade.gd`)
7. [x] Create `UpgradeEffect` base class (`scripts/upgrades/effects/upgrade_effect.gd`)

### Phase 2: Autoloads and registries ✅
8. [x] Create `UpgradeRegistry` autoload (`scripts/autoloads/upgrade_registry.gd`)
9. [x] Create `UpgradeManager` autoload (`scripts/autoloads/upgrade_manager.gd`)
10. [x] Add new signals to `EventBus`
11. [x] Register autoloads in `project.godot`

### Phase 3: Event emissions ✅
12. [x] Add `enemy_killed` emission to `Enemy.die()`
13. [x] Add `enemy_spawned` emission to `EnemySpawner._spawn_enemy_at()`
14. [x] Add `weapon_spawned` emission to `ItemSpawningManager.spawn_item()`
15. [x] Add `weapon_broken` emission to `WeaponBehaviour.destroy()`
16. [x] Add `weapon_thrown` emission to `ThrowableBehaviour.throw()`
17. [x] Add `player_dashed` emission to `DashComponent.activate()`
18. [x] Add `player_teleported` emission to `TeleportComponent._execute_teleport()`
19. [x] Add `item_picked_up` emission to `PickupableBehaviour.try_pick_up()`

### Phase 4: Debug commands
20. [ ] Add `/upgrade` commands to DebugConsole

### Phase 5: Example upgrades
21. [ ] Create example upgrade effects (HealPlayerEffect, etc.)
22. [ ] Create 3-5 example upgrade scenes (one of each type)
23. [ ] Test via console commands

### Phase 6: Future (not this PR)
- [ ] Upgrade selection UI (pick-from-3)
- [ ] Upgrade presentation triggers (room clear, chest, etc.)
- [ ] Upgrade icons and visual polish
- [ ] Meta-progression (unlock new upgrades across runs)

---

## Open decisions

- [ ] Should trigger upgrades have a visual/audio feedback when they proc?
- [ ] Should stacking increase chance (1 stack = 10%, 2 stacks = 20%) or just effect magnitude?
- [ ] How to handle upgrades that affect "currently held weapon" vs "all weapons"?
- [ ] Should there be a cap on total upgrades per run?

---

## Iteration log

*Use this section when we change scope or make implementation choices.*

- **2026-02-02**: Initial design. Scene-based upgrades, two types (trigger + weapon modifier), manual console granting for v1.
- **2026-02-02**: Phases 1-3 complete. Core infrastructure, autoloads, and event emissions implemented.
