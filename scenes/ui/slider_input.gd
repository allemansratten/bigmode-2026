extends VBoxContainer

# Exported properties to control the label text and initial input value
@export var label_text: String = "Default Label"
@export var input_value: int = 0

# Define a signal for when the input changes
signal input_changed(new_value: int)

func _ready():
	$Label.text = label_text
	$HSlider.value = input_value
	$HSlider.connect("value_changed", _on_slider_value_changed)


func set_value(new_value: int) -> void:
	$HSlider.value = new_value

# Handler for text changes
func _on_slider_value_changed(new_value: int) -> void:
	input_changed.emit(new_value)
