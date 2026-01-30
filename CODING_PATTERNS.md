# Coding Patterns & Best Practices

*Technical implementation patterns for the Bigmode 2026 project. Update as we establish conventions.*

---

## Cooldowns & Timers

**Always use Timer nodes instead of manual delta counting.**

### ❌ Anti-pattern: Manual delta counting

```gdscript
var cooldown_remaining: float = 0.0

func _process(delta: float):
    if cooldown_remaining > 0.0:
        cooldown_remaining -= delta

func try_action():
    if cooldown_remaining <= 0.0:
        do_action()
        cooldown_remaining = 5.0
```

### ✅ Preferred: Timer nodes

```gdscript
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

**Benefits:**
- Event-driven rather than polling every frame
- No wasted CPU cycles when cooldowns aren't active
- More declarative and easier to debug
- Timer state visible in editor/debugger

**Usage patterns:**

```gdscript
# Check if ready
if _timer.is_stopped():
    # cooldown finished

# Start cooldown
_timer.start(duration)

# Optional: connect to timeout signal
_timer.timeout.connect(_on_timeout)

func _on_timeout() -> void:
    # Handle cooldown completion
    pass
```

---

## [Future patterns go here]

*Add more patterns as we establish them during development.*
