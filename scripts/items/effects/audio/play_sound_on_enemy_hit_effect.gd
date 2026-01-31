extends OnEnemyHitEffect
class_name PlaySoundOnEnemyHitEffect

## Plays a sound when the weapon hits an enemy
## Attach to any item with WeaponBehaviour to play hit sounds

@export var sound: AudioStream
@export var channel: Audio.Channels = Audio.Channels.SFX
@export var volume_scale: float = 1.0


func execute(_target: Node3D, _damage_dealt: float) -> void:
	if sound and Audio:
		Audio.play_sound(sound, channel)
	else:
		push_warning("PlaySoundOnEnemyHitEffect: no sound assigned")
