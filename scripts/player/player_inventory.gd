class_name PlayerInventory
extends Node

## Player inventory system that stores up to 4 items
## Replaces the single-item holding system

signal item_added(item: Node3D, slot: int)
signal item_removed(item: Node3D, slot: int)
signal active_item_changed(item: Node3D, slot: int)

const MAX_INVENTORY_SIZE = 4

## Currently held items (null for empty slots)
var items: Array[Node3D] = []
## Currently active item index (-1 if none)
var active_item_index: int = -1
## Reference to player
var player: Node3D

## Cached weapon behaviours for active item
var _active_melee_weapon: MeleeWeaponBehaviour = null
var _active_ranged_weapon: RangedWeaponBehaviour = null


func _ready() -> void:
	player = get_parent()
	items.resize(MAX_INVENTORY_SIZE)
	for i in range(MAX_INVENTORY_SIZE):
		items[i] = null


## Add item to first available slot, returns slot index or -1 if full
func add_item(item: Node3D) -> int:
	if not item:
		return -1
	
	# Find first empty slot
	for i in range(MAX_INVENTORY_SIZE):
		if not items[i]:
			items[i] = item
			item_added.emit(item, i)
			print("PlayerInventory: Added %s to slot %d" % [item.name, i])
			
			# If no active item, make this the active one
			if active_item_index == -1:
				set_active_item(i)
			else:
				# Store item in inactive state (detached from player)
				_store_item_inactive(item)
			
			return i
	
	print("PlayerInventory: Inventory full, cannot add %s" % item.name)
	return -1


## Remove item from specific slot
func remove_item(slot: int) -> Node3D:
	if slot < 0 or slot >= MAX_INVENTORY_SIZE or not items[slot]:
		return null
	
	var item = items[slot]
	items[slot] = null
	item_removed.emit(item, slot)
	print("PlayerInventory: Removed %s from slot %d" % [item.name, slot])
	
	# If this was the active item, clear active item
	if active_item_index == slot:
		set_active_item(-1)
		# Try to set next available item as active
		for i in range(MAX_INVENTORY_SIZE):
			if items[i]:
				set_active_item(i)
				break
	
	return item


## Set which item slot is currently active
func set_active_item(slot: int) -> void:
	# Clear current active item
	if active_item_index >= 0 and items[active_item_index]:
		_deactivate_current_item()
	
	active_item_index = slot
	_active_melee_weapon = null
	_active_ranged_weapon = null
	
	if slot >= 0 and slot < MAX_INVENTORY_SIZE and items[slot]:
		_activate_current_item()
		active_item_changed.emit(items[slot], slot)
		print("PlayerInventory: Active item set to %s (slot %d)" % [items[slot].name, slot])
	else:
		active_item_changed.emit(null, -1)
		print("PlayerInventory: No active item")


## Get currently active item
func get_active_item() -> Node3D:
	if active_item_index >= 0 and active_item_index < MAX_INVENTORY_SIZE:
		return items[active_item_index]
	return null


## Get item in specific slot
func get_item(slot: int) -> Node3D:
	if slot >= 0 and slot < MAX_INVENTORY_SIZE:
		return items[slot]
	return null


## Check if inventory is full
func is_full() -> bool:
	for item in items:
		if not item:
			return false
	return true


## Get number of items in inventory
func get_item_count() -> int:
	var count = 0
	for item in items:
		if item:
			count += 1
	return count


## Get active weapon behaviours
func get_active_melee_weapon() -> MeleeWeaponBehaviour:
	return _active_melee_weapon


func get_active_ranged_weapon() -> RangedWeaponBehaviour:
	return _active_ranged_weapon


## Private: Activate current item (attach to player, cache weapon behaviours)
func _activate_current_item() -> void:
	var item = get_active_item()
	if not item:
		return
	
	# Make item visible
	item.visible = true
	
	# Attach item to player's HoldPoint
	var hold_point = player.get_node_or_null("HoldPoint")
	if not hold_point:
		hold_point = player
	
	item.reparent(hold_point)
	item.position = Vector3.ZERO
	item.rotation = Vector3.ZERO
	
	# Make item kinematic so it doesn't fall
	if item is RigidBody3D:
		var rb = item as RigidBody3D
		rb.freeze = true
	
	# Cache weapon behaviours
	_cache_weapon_behaviours(item)


## Private: Deactivate current item (store it inactive)
func _deactivate_current_item() -> void:
	var item = get_active_item()
	if not item:
		return
	
	# Store item in inactive state
	_store_item_inactive(item)


## Private: Cache weapon behaviours from item
func _cache_weapon_behaviours(item: Node3D) -> void:
	_active_melee_weapon = null
	_active_ranged_weapon = null
	
	for child in item.get_children():
		if child is MeleeWeaponBehaviour:
			_active_melee_weapon = child as MeleeWeaponBehaviour
		elif child is RangedWeaponBehaviour:
			_active_ranged_weapon = child as RangedWeaponBehaviour


## Drop active item into the world
func drop_active_item() -> void:
	if active_item_index < 0:
		return
		
	var item = get_active_item()
	if not item:
		return
	
	# Get pickupable behaviour before removing from inventory
	var pickupable = _get_pickupable_behaviour(item)
	
	# Remove from inventory
	remove_item(active_item_index)
	
	# Drop into world
	if pickupable:
		pickupable.clear_holder()
		
	# Reparent to current scene
	var scene_root = player.get_tree().current_scene
	item.reparent(scene_root)
	
	# Position item near player
	item.global_position = player.global_position + Vector3(1, 0, 0)


## Get pickupable behaviour from item
func _get_pickupable_behaviour(item: Node3D) -> PickupableBehaviour:
	for child in item.get_children():
		if child is PickupableBehaviour:
			return child as PickupableBehaviour
	return null


## Store item in inactive state (hidden from player)
func _store_item_inactive(item: Node3D) -> void:
	# Create a storage node if it doesn't exist
	var storage_node = player.get_node_or_null("InventoryStorage")
	if not storage_node:
		storage_node = Node3D.new()
		storage_node.name = "InventoryStorage"
		player.add_child(storage_node)
	
	# Move item to storage and make it invisible
	item.reparent(storage_node)
	item.visible = false
	item.position = Vector3.ZERO
	
	# Ensure it's frozen
	if item is RigidBody3D:
		var rb = item as RigidBody3D
		rb.freeze = true