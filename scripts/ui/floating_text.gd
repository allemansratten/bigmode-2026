extends Node3D
class_name FloatingText

## Floating text that rises and fades out
## Usage: FloatingText.spawn(get_tree(), global_position, "No ammo!")

## How fast the text rises (units per second)
@export var rise_speed: float = 2.5
## How long before the text disappears
@export var lifetime: float = 2.0
## Text color
@export var text_color: Color = Color.WHITE
## Font size
@export var font_size: int = 64

var _label: Label3D
var _lifetime_timer: Timer
var _tween: Tween


func _ready() -> void:
	_label = $Label3D
	if _label:
		_label.modulate = text_color
		_label.outline_modulate = Color(0, 0, 0, text_color.a)
		_label.font_size = font_size

	# Setup lifetime timer
	_lifetime_timer = Timer.new()
	_lifetime_timer.one_shot = true
	_lifetime_timer.wait_time = lifetime
	_lifetime_timer.timeout.connect(_on_lifetime_timeout)
	add_child(_lifetime_timer)
	_lifetime_timer.start()

	# Animate with tween
	_start_animation()


func _start_animation() -> void:
	_tween = create_tween()
	_tween.set_parallel(true)

	# Rise upward
	var target_y = global_position.y + rise_speed * lifetime
	_tween.tween_property(self , "global_position:y", target_y, lifetime)

	# Fade out
	if _label:
		_tween.tween_property(_label, "modulate:a", 0.0, lifetime)
		_tween.tween_property(_label, "outline_modulate:a", 0.0, lifetime)


func _on_lifetime_timeout() -> void:
	queue_free()


## Set the text to display
func set_text(text: String) -> void:
	if _label:
		_label.text = text
	else:
		# Label not ready yet, wait for ready
		await ready
		if _label:
			_label.text = text


## Static helper to spawn floating text at a position
static func spawn(tree: SceneTree, position: Vector3, text: String, color: Color = Color.WHITE) -> FloatingText:
	var scene = load("res://scenes/ui/FloatingText.tscn")
	var instance: FloatingText = scene.instantiate()
	instance.text_color = color
	tree.root.add_child(instance)
	instance.global_position = position
	instance.set_text(text)
	return instance
