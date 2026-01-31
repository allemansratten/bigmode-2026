extends OnAttackEffect
class_name PlaySoundOnAttackEffect

## Plays a sound when the weapon attacks
## Attach to any item with WeaponBehaviour to play attack sounds

@export var sound: AudioStream
@export var channel: Audio.Channels = Audio.Channels.SFX
@export var volume_scale: float = 1.0


func execute() -> void:
	if sound and Audio:
		Audio.play_sound(sound, channel)
	else:
		push_warning("PlaySoundOnAttackEffect: no sound assigned")
