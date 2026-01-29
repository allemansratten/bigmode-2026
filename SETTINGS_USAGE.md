# Settings Manager Usage Guide

The SettingsManager is a global singleton that handles persistent settings using a simple key-value API.

## Basic Usage

```gdscript
# Get a setting with a default value
var music_volume = Settings.get_value("audio", "music_volume", 0.5)

# Set a setting (auto-saves after 0.5 seconds)
Settings.set_value("audio", "music_volume", 0.8)

# Check if a setting exists
if Settings.has_setting("graphics", "fullscreen"):
    var fullscreen = Settings.get_value("graphics", "fullscreen")

# Force immediate save (bypasses debounce)
Settings.save_now()
```

## Storage Format

Settings are stored in `user://settings.cfg` as INI format:

```ini
[audio]
music_volume=0.8
sfx_volume=0.5

[graphics]
fullscreen=true
resolution_x=1920
```

## Integration Example

The AudioManager demonstrates the pattern:

```gdscript
func _ready():
    # Load from Settings on startup
    channel_volumes[Channels.Music] = Settings.get_value("audio", "music_volume", 0.3)
    update_volumes()

func set_channel_volume(channel: Channels, value: float):
    channel_volumes[channel] = value
    # Save to Settings when changed
    Settings.set_value("audio", "music_volume", value)
    update_volumes()
```

## Common Use Cases

### Graphics Settings
```gdscript
func apply_graphics_settings():
    var fullscreen = Settings.get_value("graphics", "fullscreen", false)
    var vsync = Settings.get_value("graphics", "vsync", true)

    if fullscreen:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
    DisplayServer.window_set_vsync_mode(
        DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
    )
```

### Control Remapping
```gdscript
func save_key_binding(action: String, event: InputEvent):
    Settings.set_value("controls", action, var_to_str(event))

func load_key_binding(action: String) -> InputEvent:
    var saved = Settings.get_value("controls", action, "")
    if saved:
        return str_to_var(saved)
    return null
```

## Auto-Save Behavior

- Settings are automatically saved 0.5 seconds after the last change
- This debouncing prevents excessive disk writes during rapid changes (e.g., dragging a slider)
- On exit, any unsaved changes are immediately flushed to disk
- Use `Settings.save_now()` if you need immediate persistence

## File Location

The settings file is stored at:
- **Windows**: `%APPDATA%/Godot/app_userdata/<project_name>/settings.cfg`
- **macOS**: `~/Library/Application Support/Godot/app_userdata/<project_name>/settings.cfg`
- **Linux**: `~/.local/share/godot/app_userdata/<project_name>/settings.cfg`
