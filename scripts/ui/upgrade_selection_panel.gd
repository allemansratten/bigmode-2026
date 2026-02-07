extends Control
class_name UpgradeSelectionPanel

## Displays 3 random upgrades for the player to choose from after clearing a room

signal upgrade_selected(upgrade_id: String)
signal panel_closed()

@export var card_scene: PackedScene
@export var upgrade_count: int = 3

var _upgrade_ids: Array[String] = []
var _selected_index: int = 0
var _upgrade_cards: Array[Control] = []


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_left"):
		_select_previous()
	elif event.is_action_pressed("ui_right"):
		_select_next()
	elif event.is_action_pressed("ui_accept"):
		_confirm_selection()


## Show the upgrade selection panel with random upgrades
func show_upgrades() -> void:
	# Get excluded upgrades (those at max stacks)
	var exclude: Array[String] = _get_maxed_upgrades()

	# Get random upgrade IDs
	_upgrade_ids = UpgradeRegistry.get_random_upgrades(upgrade_count, [], exclude)

	if _upgrade_ids.size() == 0:
		print("UpgradeSelectionPanel: No upgrades available!")
		panel_closed.emit()
		return

	# Clear existing cards
	_clear_cards()

	# Create upgrade cards
	var card_container = $CenterContainer/VBoxContainer/CardContainer
	for i in range(_upgrade_ids.size()):
		var upgrade_id = _upgrade_ids[i]
		var card = _create_upgrade_card(upgrade_id, i)
		card_container.add_child(card)
		_upgrade_cards.append(card)

	# Select first card
	_selected_index = 0
	_update_selection_visual()

	show()


## Hide the panel and emit closed signal
func close() -> void:
	hide()
	_clear_cards()
	panel_closed.emit()


func _clear_cards() -> void:
	for card in _upgrade_cards:
		if is_instance_valid(card):
			card.queue_free()
	_upgrade_cards.clear()


func _create_upgrade_card(upgrade_id: String, index: int) -> Control:
	var upgrade_scene = UpgradeRegistry.get_upgrade(upgrade_id)
	if not upgrade_scene:
		push_error("Failed to get upgrade: %s" % upgrade_id)
		return _create_placeholder_card(upgrade_id)

	var upgrade = upgrade_scene.instantiate() as BaseUpgrade

	# Create card container
	var card = PanelContainer.new()
	card.name = "Card_%d" % index
	card.custom_minimum_size = Vector2(200, 280)
	card.pivot_offset = card.custom_minimum_size / 2.0
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Add content
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	# Icon
	if upgrade.icon:
		var icon_rect = TextureRect.new()
		icon_rect.texture = upgrade.icon
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.custom_minimum_size = Vector2(64, 64)
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(icon_rect)

	# Name
	var name_label = Label.new()
	name_label.text = upgrade.upgrade_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	# Description
	var desc_label = RichTextLabel.new()
	desc_label.bbcode_enabled = true
	desc_label.text = upgrade.description
	desc_label.fit_content = true
	desc_label.custom_minimum_size = Vector2(180, 100)
	desc_label.scroll_active = false
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_label)

	# Stack info
	var current_stacks = UpgradeManager.get_upgrade_count(upgrade_id)
	var max_stacks_str = "∞" if upgrade.max_stacks < 0 else str(upgrade.max_stacks)
	var stack_label = Label.new()
	stack_label.text = "Stacks: %d / %s" % [current_stacks, max_stacks_str]
	stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack_label.add_theme_font_size_override("font_size", 12)
	stack_label.modulate = Color(0.7, 0.7, 0.7)
	stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(stack_label)

	# Store reference to upgrade_id in card metadata
	card.set_meta("upgrade_id", upgrade_id)
	card.set_meta("index", index)

	# Connect click
	card.gui_input.connect(_on_card_input.bind(index))

	# Clean up temporary instance
	upgrade.queue_free()

	return card


func _create_placeholder_card(upgrade_id: String) -> Control:
	var card = PanelContainer.new()
	var label = Label.new()
	label.text = "Error: %s" % upgrade_id
	card.add_child(label)
	return card


func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _selected_index == index:
			# Double-click or already selected - confirm
			_confirm_selection()
		else:
			# Select this card
			_selected_index = index
			_update_selection_visual()


func _select_previous() -> void:
	_selected_index = (_selected_index - 1 + _upgrade_cards.size()) % _upgrade_cards.size()
	_update_selection_visual()


func _select_next() -> void:
	_selected_index = (_selected_index + 1) % _upgrade_cards.size()
	_update_selection_visual()


func _update_selection_visual() -> void:
	for i in range(_upgrade_cards.size()):
		var card = _upgrade_cards[i]
		if i == _selected_index:
			# Highlight selected card
			card.modulate = Color(1.2, 1.2, 1.2)
			card.scale = Vector2(1.05, 1.05)
		else:
			card.modulate = Color(1, 1, 1)
			card.scale = Vector2(1, 1)


func _confirm_selection() -> void:
	if _selected_index < 0 or _selected_index >= _upgrade_ids.size():
		return

	var selected_id = _upgrade_ids[_selected_index]
	print("UpgradeSelectionPanel: Selected upgrade: %s" % selected_id)

	upgrade_selected.emit(selected_id)
	close()


func _get_maxed_upgrades() -> Array[String]:
	var maxed: Array[String] = []
	for upgrade_id in UpgradeRegistry.get_all_upgrade_ids():
		var upgrade_scene = UpgradeRegistry.get_upgrade(upgrade_id)
		if upgrade_scene:
			var upgrade = upgrade_scene.instantiate() as BaseUpgrade
			if upgrade:
				var current = UpgradeManager.get_upgrade_count(upgrade_id)
				if not upgrade.can_stack(current):
					maxed.append(upgrade_id)
				upgrade.queue_free()
	return maxed
