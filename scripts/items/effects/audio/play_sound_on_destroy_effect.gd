extends OnDestroyEffect
class_name PlaySoundOnDestroyEffect

## Plays a sound when the weapon/item is destroyed
## Attach to any item with WeaponBehaviour to play break sounds

@export var sound: AudioStream
@export var channel: Audio.Channels = Audio.Channels.SFX
@export var volume_scale: float = 1.0


func execute() -> void:
	if sound and Audio:
		Audio.play_sound(sound, channel)
		print("PlaySoundOnDestroyEffect: played %s" % sound.resource_path if sound.resource_path else "sound")
	else:
		push_warning("PlaySoundOnDestroyEffect: no sound assigned to %s" % get_parent().name if get_parent() else "effect")
