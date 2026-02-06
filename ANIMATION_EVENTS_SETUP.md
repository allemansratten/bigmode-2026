# Animation Events Setup

Add animation events via AnimationPlayer **Call Method tracks** targeting the `AnimationController`.

## Available Methods

| Method | Signal | Purpose |
|--------|--------|---------|
| `_anim_hit_frame()` | `hit_frame` | Weapon damage timing |
| `_anim_attack_window_open()` | `attack_window(true)` | Attack becomes active |
| `_anim_attack_window_close()` | `attack_window(false)` | Attack ends |
| `_anim_footstep()` | `footstep` | Movement audio |

## Setup Steps

1. Open model scene (e.g. `resources/models/wizard/player_character.tscn`)
2. Select AnimationPlayer, open Animation panel
3. Select the animation (e.g. `MeleeAttackKick`)
4. Add Track → Call Method Track → target: `../../AnimationController`
5. Add keyframes at the correct times

**Target path**: From AnimationPlayer up to the AnimationController on the character root:
```
Character (CharacterBody3D)
├─ Model (instanced scene)
│  ├─ AnimationPlayer          ← track is here
│  └─ AnimationTree
└─ AnimationController         ← target: ../../AnimationController
```

## Example Timelines

**Attack (~2.0s)**:
```
0.2s  _anim_attack_window_open
0.8s  _anim_hit_frame
1.2s  _anim_attack_window_close
```

**Running (looped ~1.0s)**:
```
0.3s  _anim_footstep
0.8s  _anim_footstep
```

## Weapon Integration

Melee weapons auto-connect to `hit_frame` on pickup and disconnect on drop. If no AnimationController exists, weapons fall back to tween-based timing.

## Troubleshooting

- **No events firing**: Check method track target path. Enable `debug_logging` on controller.
- **Multiple hits**: `_anim_hit_frame()` fires once per action (guarded by flag). Check for duplicate tracks.
- **Method names**: Case-sensitive — must match exactly.
