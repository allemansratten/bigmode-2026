class_name SelectionWheel
extends Control

## Selection wheel UI for inventory item selection
## Shows around mouse cursor when inventory button is held

const PlayerInventoryClass = preload("res://scripts/player/player_inventory.gd")

signal item_selected(slot: int)

@export var wheel_radius: float = 100.0
@export var item_icon_size: Vector2 = Vector2(64, 64)
@export var selection_threshold: float = 20.0  # Minimum distance from center to select
@export var background_texture: Texture2D  # Background wheel texture
@export var fallback_icons: Dictionary = {}  # Category -> Texture2D mapping

var inventory: PlayerInventoryClass
var slot_positions: Array[Vector2] = []
var slot_panels: Array[Panel] = []
var currently_hovered_slot: int = -1
var background_rect: TextureRect

## Item icon textures - you may want to replace these with actual item icons
var default_item_texture: Texture2D

func _ready() -> void:
	visible = false
	# Create default texture (white rectangle)
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0.8))
	default_item_texture = ImageTexture.new()
	default_item_texture.set_image(image)
	
	_setup_fallback_icons()
	_setup_wheel_layout()


## Set inventory reference
func set_inventory(inv: PlayerInventoryClass) -> void:
	inventory = inv


## Show the selection wheel at mouse position
func show_wheel() -> void:
	if not inventory:
		return
		
	# Ensure wheel layout is set up and size is calculated
	_setup_wheel_layout()
	
	# Position wheel at mouse cursor (center the wheel on mouse)
	var mouse_pos = get_global_mouse_position()
	global_position = mouse_pos - size / 2
	
	_update_wheel_items()
	visible = true
	currently_hovered_slot = -1


## Hide the selection wheel and select item if hovering
func hide_wheel() -> void:
	visible = false
	if currently_hovered_slot >= 0:
		item_selected.emit(currently_hovered_slot)
		print("SelectionWheel: Selected slot %d" % currently_hovered_slot)
	currently_hovered_slot = -1


func _process(_delta: float) -> void:
	if not visible:
		return
		
	_update_selection_hover()


## Setup the circular layout for 4 slots
func _setup_wheel_layout() -> void:
	slot_positions.clear()
	slot_panels.clear()
	
	# Clear existing children
	for child in get_children():
		child.queue_free()
	
	# Set control size to encompass all slots
	var wheel_size = wheel_radius * 2 + item_icon_size.x
	size = Vector2(wheel_size, wheel_size)
	
	# Add background texture if provided
	if background_texture:
		background_rect = TextureRect.new()
		background_rect.texture = background_texture
		background_rect.size = size
		background_rect.position = Vector2.ZERO
		background_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(background_rect)
	
	# Create 4 slots positioned in a circle
	for i in range(4):
		var angle = (i * PI / 2.0)  # Start at right, go clockwise: right, bottom, left, top
		var pos = Vector2(
			cos(angle) * wheel_radius,
			sin(angle) * wheel_radius
		)
		slot_positions.append(pos)
		
		# Create panel for this slot
		var panel = Panel.new()
		panel.size = item_icon_size
		# Position relative to center of the control (size/2), not top-left
		var wheel_center = Vector2(wheel_size, wheel_size) / 2
		panel.position = wheel_center + pos - item_icon_size / 2
		
		# Style the panel
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.3, 0.3, 0.3, 0.8)
		style_box.border_width_left = 2
		style_box.border_width_right = 2
		style_box.border_width_top = 2
		style_box.border_width_bottom = 2
		style_box.border_color = Color(0.6, 0.6, 0.6)
		style_box.corner_radius_bottom_left = 8
		style_box.corner_radius_bottom_right = 8
		style_box.corner_radius_top_left = 8
		style_box.corner_radius_top_right = 8
		panel.add_theme_stylebox_override("panel", style_box)
		
		add_child(panel)
		slot_panels.append(panel)
		
		# Add item icon as TextureRect
		var texture_rect = TextureRect.new()
		texture_rect.size = item_icon_size
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		panel.add_child(texture_rect)


## Update wheel to show current inventory items
func _update_wheel_items() -> void:
	if not inventory:
		return
		
	for i in range(4):
		if i < slot_panels.size():
			var panel = slot_panels[i]
			var texture_rect = panel.get_child(0) as TextureRect
			var item = inventory.get_item(i)
			
			if item:
				# Get item icon from item or use fallback
				var item_icon = _get_item_icon(item)
				texture_rect.texture = item_icon
				# Update panel color to show it has an item
				var style_box = panel.get_theme_stylebox("panel") as StyleBoxFlat
				if style_box:
					style_box.bg_color = Color(0.4, 0.4, 0.6, 0.8)
			else:
				texture_rect.texture = null
				# Update panel color to show it's empty
				var style_box = panel.get_theme_stylebox("panel") as StyleBoxFlat
				if style_box:
					style_box.bg_color = Color(0.3, 0.3, 0.3, 0.4)


## Update which slot is being hovered based on mouse position
func _update_selection_hover() -> void:
	if not inventory:
		return
		
	var local_mouse_pos = get_local_mouse_position() - size / 2
	var distance_from_center = local_mouse_pos.length()
	
	# Reset all slot highlights
	for i in range(slot_panels.size()):
		var style_box = slot_panels[i].get_theme_stylebox("panel") as StyleBoxFlat
		if style_box:
			style_box.border_color = Color(0.6, 0.6, 0.6)
	
	currently_hovered_slot = -1
	
	# Only select if far enough from center
	if distance_from_center < selection_threshold:
		return
	
	# Find closest slot to mouse
	var closest_slot = -1
	var closest_distance = INF
	
	for i in range(slot_positions.size()):
		var slot_pos = slot_positions[i]
		var distance = local_mouse_pos.distance_to(slot_pos)
		
		if distance < closest_distance:
			closest_distance = distance
			closest_slot = i
	
	# Highlight the closest slot if it has an item
	if closest_slot >= 0 and inventory.get_item(closest_slot):
		currently_hovered_slot = closest_slot
		var style_box = slot_panels[closest_slot].get_theme_stylebox("panel") as StyleBoxFlat
		if style_box:
			style_box.border_color = Color(1.0, 1.0, 0.0)  # Yellow highlight


## Setup fallback icons for different item categories
func _setup_fallback_icons() -> void:
	# Create simple colored icons for different categories
	# You can replace these with actual icon textures later
	var weapon_icon = _create_colored_icon(Color(0.8, 0.2, 0.2))  # Red for weapons
	var consumable_icon = _create_colored_icon(Color(0.2, 0.8, 0.2))  # Green for consumables
	var movement_icon = _create_colored_icon(Color(0.2, 0.2, 0.8))  # Blue for movement items
	
	# Map categories to icons (using ItemCategories enum)
	fallback_icons[10] = weapon_icon  # Category.WEAPON
	fallback_icons[13] = consumable_icon  # Category.CONSUMABLE
	fallback_icons[11] = movement_icon  # Category.MOVEMENT


## Get icon for a specific item
func _get_item_icon(item: Node3D) -> Texture2D:
	# First, try to get custom icon from SpawnableBehaviour
	var spawnable = _get_spawnable_behaviour(item)
	if spawnable and spawnable.has_method("get_icon"):
		var custom_icon = spawnable.get_icon()
		if custom_icon:
			return custom_icon
	
	# Fallback to category-based icon
	if spawnable:
		var categories = spawnable.categories
		for category in categories:
			if fallback_icons.has(category):
				return fallback_icons[category]
	
	# Final fallback to default texture
	return default_item_texture


## Get SpawnableBehaviour from item
func _get_spawnable_behaviour(item: Node3D) -> Node:
	for child in item.get_children():
		if child.get_script() and child.get_script().get_path().ends_with("spawnable_behaviour.gd"):
			return child
	return null


## Create a simple colored icon texture
func _create_colored_icon(color: Color) -> Texture2D:
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture