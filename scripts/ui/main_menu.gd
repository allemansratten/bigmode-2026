extends Node3D

@onready var play_button: Button = %PlayButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var camera: Camera3D = $Camera3D

@onready var menu_container: CenterContainer = $CanvasLayer/CenterContainer
@onready var settings_panel: CenterContainer = %SettingsPanel
@onready var mute_button: Button = %MuteButton
@onready var music_slider = %MusicVolumeSlider
@onready var sfx_slider = %SFXVolumeSlider
@onready var ambience_slider = %AmbienceVolumeSlider
@onready var back_button: Button = %BackButton

## How often a new item spawns (seconds)
@export var spawn_interval: float = 0.4
## How long items live before being freed
@export var item_lifetime: float = 10.0
## Horizontal spread around the camera's look target
@export var spawn_spread: float = 8.0
## Height above the camera to spawn items
@export var spawn_height: float = 20.0

var _spawn_timer: Timer


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	back_button.pressed.connect(_on_back_pressed)
	mute_button.pressed.connect(_on_mute_pressed)
	music_slider.input_changed.connect(_on_music_volume_changed)
	sfx_slider.input_changed.connect(_on_sfx_volume_changed)
	ambience_slider.input_changed.connect(_on_ambience_volume_changed)

	# Initialize settings UI from current values
	mute_button.text = "Unmute" if Audio.is_muted else "Mute"
	music_slider.set_value(roundi(Audio.channel_volumes[Audio.Channels.Music] * 100))
	sfx_slider.set_value(roundi(Audio.channel_volumes[Audio.Channels.SFX] * 100))
	ambience_slider.set_value(roundi(Audio.channel_volumes[Audio.Channels.Ambience] * 100))

	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = spawn_interval
	_spawn_timer.timeout.connect(_spawn_random_item)
	add_child(_spawn_timer)
	_spawn_timer.start()


func _spawn_random_item() -> void:
	if ItemRegistry.all_items.is_empty():
		return

	var item_scene: PackedScene = ItemRegistry.all_items.pick_random()
	var item := item_scene.instantiate() as Node3D
	if not item:
		return

	add_child(item)
	item.scale = Vector3(2, 2, 2)

	# Position above the camera's view with random horizontal spread
	var cam_pos := camera.global_position
	item.global_position = Vector3(
		cam_pos.x + randf_range(-spawn_spread, spawn_spread),
		cam_pos.y + spawn_height,
		cam_pos.z + randf_range(-spawn_spread, spawn_spread),
	)

	# Unfreeze RigidBody so gravity pulls it down, but slow the fall
	var rb := item as RigidBody3D
	if rb:
		rb.freeze = false
		rb.gravity_scale = 0.15

	# Gentle constant angular velocity so they tumble slowly
	if rb:
		rb.angular_velocity = Vector3(
			randf_range(-0.5, 0.5),
			randf_range(-0.5, 0.5),
			randf_range(-0.5, 0.5),
		)

	# Cleanup timer
	var cleanup_timer := Timer.new()
	cleanup_timer.one_shot = true
	cleanup_timer.wait_time = item_lifetime
	cleanup_timer.timeout.connect(item.queue_free)
	cleanup_timer.timeout.connect(cleanup_timer.queue_free)
	add_child(cleanup_timer)
	cleanup_timer.start()


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_settings_pressed() -> void:
	menu_container.hide()
	settings_panel.show()


func _on_back_pressed() -> void:
	settings_panel.hide()
	menu_container.show()


func _on_mute_pressed() -> void:
	Audio.toggle_mute()
	mute_button.text = "Unmute" if Audio.is_muted else "Mute"


func _on_music_volume_changed(new_value: int) -> void:
	Audio.set_channel_volume(Audio.Channels.Music, float(new_value) / 100)


func _on_sfx_volume_changed(new_value: int) -> void:
	Audio.set_channel_volume(Audio.Channels.SFX, float(new_value) / 100)


func _on_ambience_volume_changed(new_value: int) -> void:
	Audio.set_channel_volume(Audio.Channels.Ambience, float(new_value) / 100)


func _on_quit_pressed() -> void:
	get_tree().quit()
