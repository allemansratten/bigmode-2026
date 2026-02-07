extends CanvasLayer

@onready var pause_menu = $PauseMenu
@onready var basic_obverlay = $BasicOverlay
@onready var wave_label: Label = $BasicOverlay/WaveLabel
@onready var health_container: HBoxContainer = $BasicOverlay/HealthContainer

var _health_circles: Array[Label] = []

## Set the initial settings UI values based on the real values
func _ready() -> void:
	var music_volume_slider = get_node("PauseMenu/MenuButtonsContainer/MusicVolumeSlider")
	music_volume_slider.set_value(round(Audio.channel_volumes[Audio.Channels.Music] * 100))
	var mute_button = get_node("PauseMenu/MenuButtonsContainer/MuteButton")
	mute_button.text = "Unmute" if Audio.is_muted else "Mute"

	# Connect wave signals
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.room_cleared.connect(_on_room_cleared)

	# Hide wave label initially
	if wave_label:
		wave_label.hide()

	# Connect to player health
	_connect_to_player()


func _connect_to_player() -> void:
	# Wait a frame for player to be ready
	await get_tree().process_frame
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("health_changed"):
		player.health_changed.connect(_on_player_health_changed)
		# Initialize health display
		_update_health_display(player.current_health, player.max_health)


func _on_player_health_changed(current: float, maximum: float) -> void:
	_update_health_display(current, maximum)


func _update_health_display(current: float, maximum: float) -> void:
	if not health_container:
		return

	var health_int := int(current)
	var max_health_int := int(maximum)

	# Add more circles if needed
	while _health_circles.size() < max_health_int:
		var circle := Label.new()
		circle.text = "●"
		circle.add_theme_font_size_override("font_size", 40)
		circle.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
		health_container.add_child(circle)
		_health_circles.append(circle)

	# Remove excess circles if max health decreased
	while _health_circles.size() > max_health_int:
		var circle = _health_circles.pop_back()
		circle.queue_free()

	# Update visibility based on current health
	for i in range(_health_circles.size()):
		_health_circles[i].visible = i < health_int


func _on_wave_started(wave_number: int) -> void:
	if wave_label:
		wave_label.text = str(wave_number)
		wave_label.show()


func _on_room_cleared(_room: Node3D) -> void:
	if wave_label:
		wave_label.hide()


func toggle_pause() -> void:
	pause_menu.visible = !pause_menu.visible
	basic_obverlay.visible = !basic_obverlay.visible

	if get_tree().paused:
		EventBus.emit_game_resumed()
	else:
		EventBus.emit_game_paused()


func _on_mute_button_pressed() -> void:
	var mute_button = get_node("PauseMenu/MenuButtonsContainer/MuteButton")
	Audio.toggle_mute()
	mute_button.text = "Unmute" if Audio.is_muted else "Mute"


func _on_music_volume_slider_input_changed(new_value: int) -> void:
	var normalized_value = float(new_value) / 100
	Audio.set_channel_volume(Audio.Channels.Music, normalized_value)
