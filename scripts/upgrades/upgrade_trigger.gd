class_name UpgradeTrigger

## Defines trigger types for event-driven upgrades
## Used by TriggerUpgrade to specify which event to listen for

enum Type {
	# Combat triggers
	ENEMY_KILLED,           # Any enemy killed
	ENEMY_SPAWNED,          # Enemy appears in room
	DAMAGE_DEALT,           # Player deals damage
	DAMAGE_TAKEN,           # Player takes damage

	# Weapon triggers
	WEAPON_THROWN,          # Player throws a weapon
	WEAPON_BROKEN,          # Weapon durability reaches 0
	WEAPON_ATTACK,          # Weapon attacks (melee swing, ranged shot)
	CROWD_THROW,            # Crowd throws an item

	# Movement triggers
	PLAYER_DASHED,          # Player uses dash
	PLAYER_TELEPORTED,      # Player uses teleport

	# Item triggers
	ITEM_PICKED_UP,         # Player picks up any item
	ITEM_DROPPED,           # Player drops an item

	# Room triggers
	ROOM_ENTERED,           # Player enters new room
	ROOM_CLEARED,           # All enemies in room defeated
}


## Get a human-readable name for a trigger type
static func get_trigger_name(trigger: Type) -> String:
	match trigger:
		Type.ENEMY_KILLED: return "Enemy Killed"
		Type.ENEMY_SPAWNED: return "Enemy Spawned"
		Type.DAMAGE_DEALT: return "Damage Dealt"
		Type.DAMAGE_TAKEN: return "Damage Taken"
		Type.WEAPON_THROWN: return "Weapon Thrown"
		Type.WEAPON_BROKEN: return "Weapon Broken"
		Type.WEAPON_ATTACK: return "Weapon Attack"
		Type.CROWD_THROW: return "Crowd Throw"
		Type.PLAYER_DASHED: return "Player Dashed"
		Type.PLAYER_TELEPORTED: return "Player Teleported"
		Type.ITEM_PICKED_UP: return "Item Picked Up"
		Type.ITEM_DROPPED: return "Item Dropped"
		Type.ROOM_ENTERED: return "Room Entered"
		Type.ROOM_CLEARED: return "Room Cleared"
		_: return "Unknown"
