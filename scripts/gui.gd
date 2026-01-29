extends CanvasLayer

@onready var pause_menu = $PauseMenu
@onready var basic_obverlay = $BasicOverlay

## Set the initial settings UI values based on the real values
func _ready() -> void:
	var music_volume_slider = get_node("PauseMenu/MenuButtonsContainer/MusicVolumeSlider")
	music_volume_slider.set_value(round(Audio.channel_volumes[Audio.Channels.Music] * 100))


func toggle_pause() -> void:
	pause_menu.visible = !pause_menu.visible

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
