extends OnThrowLandedEffect
class_name PlaySoundOnThrowLandedEffect

## Plays a sound when a thrown item lands
## Attach to any item with ThrowableBehaviour to play impact sounds

@export var sound: AudioStream
@export var channel: Audio.Channels = Audio.Channels.SFX
@export var volume_scale: float = 1.0


func execute(_collision_body: Node) -> void:
	if sound and Audio:
		Audio.play_sound(sound, channel)
	else:
		push_warning("PlaySoundOnThrowLandedEffect: no sound assigned")
