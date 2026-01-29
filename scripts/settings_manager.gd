extends Node

## Global singleton for managing game settings
## Provides a simple API to get/set settings with automatic persistence
## Settings are saved to user://settings.cfg in INI format
##
## Usage:
## ```
## # Get a setting with a default value
## var volume = Settings.get_value("audio", "music_volume", 0.5)
##
## # Set a setting (auto-saves after a short delay)
## Settings.set_value("audio", "music_volume", 0.8)
## ```

const SETTINGS_PATH = "user://settings.cfg"
const SAVE_DELAY = 0.5  # Seconds to wait before saving (debounce)

var _config: ConfigFile
var _save_timer: Timer
var _dirty: bool = false

func _ready():
	_config = ConfigFile.new()

	# Setup auto-save timer
	_save_timer = Timer.new()
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.one_shot = true
	_save_timer.timeout.connect(_save_to_disk)
	add_child(_save_timer)

	# Load existing settings
	_load_from_disk()


## Get a setting value with a default fallback
## Returns the default if the section/key doesn't exist
func get_value(section: String, key: String, default = null):
	return _config.get_value(section, key, default)


## Set a setting value and trigger an auto-save
## The save is debounced to avoid excessive disk writes
func set_value(section: String, key: String, value) -> void:
	_config.set_value(section, key, value)
	_dirty = true

	# Restart the save timer (debounce)
	if _save_timer.is_stopped():
		_save_timer.start()
	else:
		_save_timer.start(SAVE_DELAY)


## Check if a section and key exist in the settings
func has_setting(section: String, key: String) -> bool:
	return _config.has_section_key(section, key)


## Get all keys in a section
func get_section_keys(section: String) -> PackedStringArray:
	if _config.has_section(section):
		return _config.get_section_keys(section)
	return PackedStringArray()


## Force an immediate save to disk (bypasses debounce)
func save_now() -> void:
	_save_timer.stop()
	_save_to_disk()


## Load settings from disk
func _load_from_disk() -> void:
	var error = _config.load(SETTINGS_PATH)
	if error == OK:
		print("Settings loaded from: ", SETTINGS_PATH)
	elif error == ERR_FILE_NOT_FOUND:
		print("No settings file found, using defaults")
	else:
		push_error("Failed to load settings: ", error)


## Save settings to disk
func _save_to_disk() -> void:
	if not _dirty:
		return

	var error = _config.save(SETTINGS_PATH)
	if error == OK:
		_dirty = false
		print("Settings saved to: ", SETTINGS_PATH)
	else:
		push_error("Failed to save settings: ", error)


## Called when the node is about to be removed from the scene tree
## Ensures any pending changes are saved
func _exit_tree():
	if _dirty:
		_save_to_disk()
