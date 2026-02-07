extends Node3D

@onready var play_button: Button = %PlayButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var camera: Camera3D = $Camera3D

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
	print("Settings menu not yet implemented.")


func _on_quit_pressed() -> void:
	get_tree().quit()
