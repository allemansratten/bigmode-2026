extends Node

# Playlist of music tracks
@onready var music_playlist: Array[AudioStream] = [
	# preload("res://resources/music/gamejam_LD48.ogg"),
	preload("res://resources/sounds/ambient-noise-loop.mp3"),
]
var current_track_index: int = 0

@onready var audio_manager = EventBus

func _ready():
	# Connect to the AudioManager's music_finished signal
	Audio.music_finished.connect(_on_music_finished)
	# Start playing the first track
	play_next_track()


func _on_music_finished():
	play_next_track()


func play_next_track() -> void:
	if music_playlist.size() <= 0:
		return

	# Play the next track
	var next_track = music_playlist[current_track_index]
	Audio.play_sound(next_track, Audio.Channels.Music)

	# Update the track index for the next time
	current_track_index = (current_track_index + 1) % music_playlist.size()
