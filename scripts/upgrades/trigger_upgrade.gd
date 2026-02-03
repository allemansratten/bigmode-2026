extends Node
class_name TriggerUpgrade

## Component for event-driven upgrades
## Listens for a specific trigger event, rolls chance, and executes child effects
## Attach as child of BaseUpgrade, with UpgradeEffect children

## Which event triggers this upgrade
@export var trigger: UpgradeTrigger.Type = UpgradeTrigger.Type.ENEMY_KILLED

## Probability of activation (0.0 - 1.0)
@export_range(0.0, 1.0) var chance: float = 1.0

## Minimum time between activations (0 = no cooldown)
@export var cooldown: float = 0.0

## Only trigger for items/enemies with this name (empty = any)
## Checked against context["item_name"] or context["weapon"].name
@export var item_name_filter: String = ""

## Only trigger every Nth occurrence (0 = every time)
## Useful for "every 10th kill" type upgrades
@export var trigger_every_n: int = 0

## Reference to parent BaseUpgrade
var base_upgrade: BaseUpgrade

## Cooldown timer
var _cooldown_timer: Timer

## Whether currently on cooldown
var _on_cooldown: bool = false

## Counter for trigger_every_n
var _trigger_counter: int = 0


func _ready() -> void:
	base_upgrade = get_parent() as BaseUpgrade
	if not base_upgrade:
		push_warning("TriggerUpgrade: must be child of BaseUpgrade")

	# Setup cooldown timer if needed
	if cooldown > 0.0:
		_cooldown_timer = Timer.new()
		_cooldown_timer.one_shot = true
		_cooldown_timer.timeout.connect(_on_cooldown_finished)
		add_child(_cooldown_timer)


## Called by UpgradeManager when the trigger event fires
## context: Dictionary with event-specific data (enemy, position, weapon, etc.)
## stacks: Number of times this upgrade has been acquired
## Returns true if the upgrade activated
func try_activate(context: Dictionary, stacks: int = 1) -> bool:
	# Check cooldown
	if _on_cooldown:
		return false

	# Check item name filter
	if not _passes_item_filter(context):
		return false

	# Check every-N counter
	if trigger_every_n > 0:
		_trigger_counter += 1
		if _trigger_counter < trigger_every_n:
			return false
		_trigger_counter = 0  # Reset counter when we hit the milestone

	# Roll chance (stacking can increase chance if desired)
	var effective_chance = chance * stacks
	effective_chance = minf(effective_chance, 1.0)  # Cap at 100%

	if randf() > effective_chance:
		return false

	# Execute all child effects
	_execute_effects(context, stacks)

	# Start cooldown
	if cooldown > 0.0 and _cooldown_timer:
		_on_cooldown = true
		_cooldown_timer.start(cooldown)

	return true


## Check if the context matches the item name filter
func _passes_item_filter(context: Dictionary) -> bool:
	if item_name_filter.is_empty():
		return true

	# Check item_name in context (set by UpgradeManager)
	if context.has("item_name"):
		return context["item_name"] == item_name_filter

	# Check weapon node name
	if context.has("weapon") and context["weapon"]:
		return context["weapon"].name == item_name_filter

	# Check item node name
	if context.has("item") and context["item"]:
		return context["item"].name == item_name_filter

	return true  # No item to filter on


## Execute all UpgradeEffect children
func _execute_effects(context: Dictionary, stacks: int) -> void:
	for child in get_children():
		if child is UpgradeEffect:
			child.execute(context, stacks)


func _on_cooldown_finished() -> void:
	_on_cooldown = false


## Get human-readable trigger name
func get_trigger_name() -> String:
	return UpgradeTrigger.get_trigger_name(trigger)
