# TimeScaleManager Usage Examples

The TimeScaleManager provides global bullet time / game speed control with smooth transitions and audio pitch matching.

**Note:** Time scale is clamped to 0.01 - 1.0 range. Values below 0.01 would freeze the system (tweens/timers stop working at true 0).

## Basic Usage

### Auto-Cancel (Timed Effects)

```gdscript
# Enemy death slowdown - 0.8x speed for 0.5 seconds
func _on_enemy_died() -> void:
    TimeScaleManager.request_time_scale(0.8, 0.5)

# Post-dash slowdown - 0.6x speed for 0.3 seconds
func _on_dash_completed() -> void:
    TimeScaleManager.request_time_scale(0.6, 0.3)
```

### Manual Cancel (Input-Based Effects)

```gdscript
# Item selection UI - 0.1x speed while Tab held
var _item_menu_slowdown_id: String

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("inventory_select"):
        _item_menu_slowdown_id = TimeScaleManager.request_time_scale(0.1)
    elif event.is_action_released("inventory_select"):
        TimeScaleManager.cancel_time_scale(_item_menu_slowdown_id)
```

```gdscript
# Aiming slowdown - 0.4x speed while aiming
var _aim_slowdown_id: String

func start_aiming() -> void:
    # Faster transition for responsive feel
    _aim_slowdown_id = TimeScaleManager.request_time_scale(0.4, -1, 0.05)

func stop_aiming() -> void:
    TimeScaleManager.cancel_time_scale(_aim_slowdown_id, 0.05)
```

### Advanced: Custom Transition Times

```gdscript
# Instant transition (no smoothing)
TimeScaleManager.request_time_scale(0.1, -1, 0.0)

# Slow transition (0.5 seconds)
TimeScaleManager.request_time_scale(0.5, 3.0, 0.5)

# Default transition (0.15 seconds)
TimeScaleManager.request_time_scale(0.3, 2.0)
```

## Multiple Simultaneous Effects

**The slowest speed always wins:**

```gdscript
# Scenario: Multiple effects active at once
var aim_id = TimeScaleManager.request_time_scale(0.4)      # 0.4x speed
TimeScaleManager.request_time_scale(0.8, 0.5)              # 0.8x speed for 0.5s

# Result: 0.4x speed is applied (slowest wins)
# After aim is canceled: 0.8x speed takes over (if still active)
# After both end: 1.0x speed (normal)
```

## Listening to Time Scale Changes

```gdscript
func _ready() -> void:
    TimeScaleManager.time_scale_changed.connect(_on_time_scale_changed)

func _on_time_scale_changed(new_scale: float) -> void:
    print("Time scale changed to: ", new_scale)
    # Update UI, particles, or other effects
```

## Debug Commands

```bash
# Set time scale manually (clears all effects)
timescale 0.5

# Clear all effects and return to normal speed
timescale_clear
```

## Implementation Notes

- **Audio**: Pitch automatically adjusts to match time scale (handled by AudioManager)
- **Physics**: Affected by `Engine.time_scale` (no special handling needed)
- **Particles**: Affected by `Engine.time_scale` (no special handling needed)
- **Animations**: May need `speed_scale` adjustments for specific animations if you want them unaffected
- **Timers**: Affected by time scale (use `process_mode = TIMER_PROCESS_PHYSICS` to be unaffected)

## Common Patterns

### Ability with Windup Slowdown

```gdscript
var _charge_slowdown_id: String

func start_charge() -> void:
    _charge_slowdown_id = TimeScaleManager.request_time_scale(0.3)

func release_charge() -> void:
    TimeScaleManager.cancel_time_scale(_charge_slowdown_id)
    # Brief speed up for impact feel
    TimeScaleManager.request_time_scale(1.2, 0.2)
```

### Danger Detection Slowdown

```gdscript
func _on_projectile_near_player() -> void:
    # 0.5x speed for 1 second to allow dodge
    TimeScaleManager.request_time_scale(0.5, 1.0)
```

### Boss Phase Transition

```gdscript
func _on_boss_phase_change() -> void:
    # Dramatic slowdown with smooth transition
    TimeScaleManager.request_time_scale(0.2, 2.0, 0.5)
```
