extends CanvasLayer


signal code_executed(code_text)

@onready var command_input = $CodeEditor
@onready var message_label = $Label

func process_code():
	var code_text = command_input.text.strip_edges()
	
	if code_text != "":
		code_executed.emit(code_text)
		message_label.text = "Code run!"
	else:
		message_label.text = "Error: No code entered."


func _on_button_pressed() -> void:
	process_code()
