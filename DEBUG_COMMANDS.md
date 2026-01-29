# Debug Console Commands

The Debug Console allows developers to quickly test and manipulate game state during development.

## Existing Commands

- `/help` - Show all registered commands
- `/clear` - Clear console output
- `/mute` - Toggle audio mute
- `/timescale <value>` - Set time scale (e.g., `/timescale 0.5` for slow-mo)

## Adding New Commands

Add commands by connecting to the `command_entered` signal in any script:

```gdscript
func _ready():
    DebugConsole.register_command("mycommand", "Description for /help")
    DebugConsole.command_entered.connect(_on_debug_command)

func _on_debug_command(cmd: String, args: PackedStringArray):
    match cmd:
        "mycommand":
            # Handle command
            DebugConsole.debug_log("Command executed!")
```

## Common Patterns

### Simple Toggle
```gdscript
"god":
    invincible = !invincible
    DebugConsole.debug_log("God mode: " + str(invincible))
```

### Single Argument
```gdscript
"health":
    if args.size() > 0:
        health = int(args[0])
        DebugConsole.debug_log("Health set to " + str(health))
    else:
        DebugConsole.debug_warn("Usage: /health <amount>")
```

### Multiple Arguments
```gdscript
"teleport":
    if args.size() >= 2:
        position = Vector2(float(args[0]), float(args[1]))
        DebugConsole.debug_log("Teleported to " + str(position))
```

### Quoted Arguments (for spaces)
```gdscript
# Usage: /message "Hello World"
"message":
    if args.size() > 0:
        show_message(args[0])  # Gets "Hello World" as single arg
```

## Logging

```gdscript
DebugConsole.debug_log("Info message")      # White
DebugConsole.debug_warn("Warning")          # Yellow
DebugConsole.debug_error("Error")           # Red
```
