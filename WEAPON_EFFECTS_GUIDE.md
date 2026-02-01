# Weapon Effects Guide

Guide for creating weapons with custom effects using the composition-based effect system.

## Quick Start (For Non-Developers)

**Want to add a glass break sound to a weapon?**

1. Open your weapon scene (e.g., `scenes/items/Brick.tscn`)
2. Add a container: Right-click root → Add Child Node → Node → Name it "AudioEffects"
3. In FileSystem, navigate to `scenes/effects/audio/`
4. **Drag** `PlaySoundOnDestroyEffect.tscn` into the AudioEffects container
5. Select it → In Inspector → **Drag your .wav file** into the "Sound" property
6. Save!

Your weapon now plays a sound when it breaks. No coding required!

**Want an explosive sword?**

1. Open `scenes/items/Sword.tscn`
2. Add a container: Right-click root → Add Child Node → Node → Name it "Effects"
3. **Drag** `ExplosionEffect.tscn` into the Effects container
4. **Configure** properties in Inspector
5. Save!

## How It Works

Instead of creating custom scripts for each weapon type, you can **attach effect components** to any weapon to add special behaviors. Effects are modular and can be mixed and matched.

## Creating a Basic Weapon

Every throwable weapon needs these core components:

1. **RigidBody3D** (root) - the physical object
2. **PickupableBehaviour** - makes it pickupable
3. **ThrowableBehaviour** - makes it throwable
4. **SpawnableBehaviour** - makes it spawn in rooms
5. **WeaponBehaviour** - handles durability and destruction

Optional for melee attacks:
6. **MeleeWeaponBehaviour** - adds melee attack ability

## Adding Effects

Effects are separate nodes you attach as children of the weapon. They automatically trigger at specific events.

### Organizing Effects with Containers

**Recommended**: Group effects in container nodes for clean scene organization:

```
Sword (RigidBody3D)
├── [Visuals]
├── [Behaviors]
├── AudioEffects (Node)
│   ├── PlaySoundOnAttackEffect
│   ├── PlaySoundOnEnemyHitEffect
│   └── PlaySoundOnDestroyEffect
└── VisualEffects (Node)
    ├── ExplosionEffect
    └── TrailParticlesEffect
```

**Benefits:**
- Cleaner scene tree (collapsible containers)
- Easy to find and manage effects
- Group by type (audio, visual, gameplay)
- Scales well with many effects

**Note:** Effects work in containers OR as direct children - both work!

### Available Effects

#### OnDestroyEffect
Triggers when the weapon breaks (durability reaches 0).

**ExplosionEffect** - Creates explosion on destruction
```
Properties:
- explosion_radius: float
- explosion_damage: float
- knockback_force: float
```

#### OnThrowEffect
Triggers when the item is thrown.

Examples: trail particles, sound effects, temporary buffs

```gdscript
func execute(direction: Vector3, force: float, from_crowd: bool) -> void
```

#### OnThrowLandedEffect
Triggers when a thrown item lands (first collision only).

Examples: impact particles, ground effects, camera shake

```gdscript
func execute(collision_body: Node) -> void
```

#### OnAttackEffect
Triggers when weapon performs an attack (melee or ranged).

Examples: attack particles, sound effects, screen shake

```gdscript
func execute() -> void
```

#### OnEnemyHitEffect
Triggers when weapon hits an enemy.

Examples: lifesteal, status effects (poison, burn), bonus damage

```gdscript
func execute(target: Node3D, damage_dealt: float) -> void
```

#### OnEnemyKilledEffect
Triggers when weapon kills an enemy.

Examples: heal on kill, explosion on kill, spawn powerup

```gdscript
func execute(target: Node3D) -> void
```

#### OnPickupEffect
Triggers when item is picked up by player.

Examples: sound effects, particles, UI notifications, player buffs

```gdscript
func execute(picker: Node3D) -> void
```

### Audio Effects

Add sounds to weapons by dragging pre-built audio effect scenes from `scenes/effects/audio/`.

#### How to Add Sound to Any Action

1. Open your weapon scene (e.g., `Sword.tscn`)
2. Add "AudioEffects" container node (right-click root → Add Child Node → Node)
3. Navigate to `scenes/effects/audio/` in FileSystem
4. **Drag the effect scene** into AudioEffects container:
   - `PlaySoundOnDestroyEffect.tscn` - when weapon breaks
   - `PlaySoundOnAttackEffect.tscn` - when player attacks
   - `PlaySoundOnEnemyHitEffect.tscn` - when hit connects with enemy
   - `PlaySoundOnThrowLandedEffect.tscn` - when thrown item lands
5. Select the effect → Inspector → **drag your sound file** into "Sound" property
6. Save!

**Common setups:**
- **Metal sword**: attack → `metal_impact_light.wav`, destroy → `metal_break.wav`
- **Wood crate**: throw landed → `wood_impact_heavy.wav`, destroy → `wood_break_splinter.wav`
- **Brick**: throw landed → `stone_impact.wav`, destroy → `stone_break_crumble.wav`

## Examples

### Example 1: Simple Throwable Flask
```
Flask (RigidBody3D)
├── PickupableBehaviour
├── ThrowableBehaviour
├── SpawnableBehaviour
└── WeaponBehaviour (durability: 1)
```

### Example 2: Explosive Sword (Melee + Explosion)
```
ExplosiveSword (RigidBody3D)
├── PickupableBehaviour
├── ThrowableBehaviour
├── SpawnableBehaviour
├── MeleeWeaponBehaviour (durability: 10, damage: 25)
└── ExplosionEffect (radius: 3.0, damage: 30)
```

### Example 3: Lifesteal Dagger
```
LifestealDagger (RigidBody3D)
├── PickupableBehaviour
├── ThrowableBehaviour
├── SpawnableBehaviour
├── MeleeWeaponBehaviour (durability: 15, damage: 20)
└── LifestealEffect (heal_percent: 0.25)
```
*Heals player for 25% of damage dealt!*

## Step-by-Step: Creating a New Weapon in Godot Editor

1. **Create new scene** (RigidBody3D)
2. **Add mesh and collision shape** for visuals
3. **Add PickupableBehaviour** (Area3D) with collision shape
4. **Add ThrowableBehaviour** (Node) - configure throw_force
5. **Add SpawnableBehaviour** (Node) - set categories
6. **Add WeaponBehaviour** (Node) - set max_durability, damage
7. **Optional: Add MeleeWeaponBehaviour** instead of WeaponBehaviour for melee
8. **Drag and drop effects** from `scenes/effects/` folder:
   - Find effect in FileSystem panel (left side)
   - Drag it onto your item in Scene tree
   - Configure properties in Inspector
9. **Configure RigidBody**:
   - collision_layer = 8 (item)
   - collision_mask = 17 (environment + enemy)
   - contact_monitor = true
   - max_contacts_reported = 4

10. **Save scene** to `scenes/items/`

Done! ItemRegistry will auto-discover your weapon.

## Quick Add: Drag & Drop Effects

All effects are available as pre-configured scenes in `scenes/effects/`:

**Base Effect Templates** (extend these to create custom effects):
- `OnDestroyEffect.tscn`
- `OnThrowEffect.tscn`
- `OnThrowLandedEffect.tscn`
- `OnAttackEffect.tscn`
- `OnEnemyHitEffect.tscn`
- `OnEnemyKilledEffect.tscn`
- `OnPickupEffect.tscn`

**Ready-to-Use Effects**:
- `ExplosionEffect.tscn` - Explodes on destruction

Just **drag** from FileSystem → **drop** onto your item → **configure** in Inspector!

## Creating Custom Effects

To create a new effect type:

1. Create a new script extending `OnDestroyEffect`
2. Override the `execute()` function
3. Add @export variables for configuration
4. Attach it to any weapon!

Example:
```gdscript
extends OnDestroyEffect
class_name PoisonCloudEffect

@export var cloud_radius: float = 2.0
@export var damage_per_second: float = 5.0
@export var duration: float = 5.0

func execute() -> void:
    print("Spawning poison cloud!")
    # TODO: Implement poison cloud logic
```

## Future Effect Types

Ideas for more effects:

**OnDestroyEffect:**
- **FireEffect** - Sets area on fire
- **IceEffect** - Freezes ground/enemies
- **ShardEffect** - Spawns sharp fragments that damage enemies

**OnThrowEffect:**
- **TrailEffect** - Particle trail while flying
- **WhirlwindEffect** - Creates wind effect while airborne

**OnAttackEffect:**
- **ScreenShakeEffect** - Camera shake on attack
- **SlowMotionEffect** - Bullet time on attack

**OnEnemyHitEffect:**
- **LifestealEffect** - Heal player based on damage dealt
- **PoisonEffect** - Apply poison damage over time
- **StunEffect** - Temporarily disable enemy

**OnEnemyKilledEffect:**
- **HealOnKillEffect** - Restore player health
- **PowerupSpawnEffect** - Drop special items
- **ChainExplosionEffect** - Explode and damage nearby enemies

**OnPickupEffect:**
- **SoundEffect** - Play pickup sound
- **BuffEffect** - Grant temporary player buff
- **UINotificationEffect** - Show pickup message
