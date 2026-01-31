extends Node

enum Channels { Music, SFX, Ambience }

## This is a global singleton that manages audio playback on different channels
## To play a sound, first load your sound resource and then call `play_sound`
## ```
## var sound = preload('res://path/to/sound.wav')
## Audio.play_sound(sound, Audio.Channels.SFX)
## ```
## It uses a pool of AudioStreamPlayers for each channel to allow multiple sounds to play simultaneously

## Holds a pool of AudioStreamPlayers for each channel
var channel_players = {
	Channels.Music: [],
	Channels.SFX: [],
	Channels.Ambience: []
}
## Volume settings for channels (loaded from Settings at startup)
var channel_volumes = {
	Channels.Music: 0.3,
	Channels.SFX: 0.5,
	Channels.Ambience: 0.5
}
## Global mute
var is_muted: bool = false
## Number of simultaneous SFX tracks allowed
@export var MAX_SFX_PLAYERS = 5

# Define signal for when music finishes
signal music_finished()

func _ready():
	# Load volume settings from Settings
	channel_volumes[Channels.Music] = Settings.get_value("audio", "music_volume", 0.3)
	channel_volumes[Channels.SFX] = Settings.get_value("audio", "sfx_volume", 0.5)
	channel_volumes[Channels.Ambience] = Settings.get_value("audio", "ambience_volume", 0.5)
	is_muted = Settings.get_value("audio", "muted", false)

	# Pool setup for Music and Ambience (single player each)
	channel_players[Channels.Music].append($MusicPlayer)
	channel_players[Channels.Ambience].append($AmbiencePlayer)

	# Create a pool of AudioStreamPlayers for SFX
	for i in range(MAX_SFX_PLAYERS):
		var sfx_player = AudioStreamPlayer.new()
		add_child(sfx_player)  # Add dynamically to the scene
		channel_players[Channels.SFX].append(sfx_player)

	# Apply loaded mute state and volumes
	if is_muted:
		$MusicPlayer.volume_db = -80
		for channel in [Channels.SFX, Channels.Ambience]:
			for player in channel_players[channel]:
				player.stop()
	else:
		update_volumes()

	# Register debug commands
	DebugConsole.register_command("mute", "Toggle audio mute")
	DebugConsole.command_entered.connect(_on_debug_command)


## Method to play sounds on specific channels
## Checks for available channels and plays the sound
## If the channel is Music, the current music will be replaced
func play_sound(sound: AudioStream, channel: Channels) -> void:
	if is_muted:
		return

	# Special case for Music channel - replace current music
	if channel == Channels.Music:
		$MusicPlayer.stream = sound
		$MusicPlayer.play()
		return

	# Find an available player in the channel pool
	# If none available, the sound will not play
	# TODO: Handle this case differently, like replacing low priority sounds
	var available_player = get_available_player(channel)
	if available_player:
		available_player.stream = sound
		available_player.play()


## Get an available AudioStreamPlayer from a channel's pool (returns null if none available)
func get_available_player(channel: Channels) -> AudioStreamPlayer:
	for player in channel_players[channel]:
		if not player.is_playing():
			return player
	# If no player is available, return null (or handle differently, like replacing low priority sounds)
	return null


## Update the volume for each channel
func update_volumes() -> void:
	for channel in channel_players.keys():
		# Set volume for all players in the channel pool
		for player in channel_players[channel]:
			player.volume_db = linear_to_db(channel_volumes[channel])


## Mute or unmute all channels
func toggle_mute() -> void:
	is_muted = !is_muted
	Settings.set_value("audio", "muted", is_muted)
	if is_muted:
		# For music, only turn off the volume to avoid stopping the music loop
		$MusicPlayer.volume_db = -80
		# Stop all players of channel pools
		for channel in [Channels.SFX, Channels.Ambience]:
			for player in channel_players[channel]:
				player.stop()
	else:
		update_volumes()


## Set the volume for a specific channel and save to Settings
func set_channel_volume(channel: Channels, value: float) -> void:
	channel_volumes[channel] = value

	# Save to Settings based on channel
	match channel:
		Channels.Music:
			Settings.set_value("audio", "music_volume", value)
		Channels.SFX:
			Settings.set_value("audio", "sfx_volume", value)
		Channels.Ambience:
			Settings.set_value("audio", "ambience_volume", value)

	if not is_muted:
		update_volumes()
	


## Re-emit the music_finished signal when the music player finishes
func _on_music_player_finished() -> void:
	music_finished.emit()


## Handle debug console commands
func _on_debug_command(cmd: String, _args: PackedStringArray) -> void:
	match cmd:
		"mute":
			toggle_mute()
			DebugConsole.debug_log("Audio muted: " + str(is_muted))
