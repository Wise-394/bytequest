extends Area2D

# --- Member Variables ---

# A dictionary to map command strings to function names.
var command_map = {
	"move": "move_in_direction",
	"turn_left": "turn_left",
	"turn_right": "turn_right"
}

# The queue to hold commands for the interpreter to execute.
var command_queue = []

# State flag to prevent new commands from being processed while busy.
var is_executing = false

# Player's current grid position, used for calculations.
var currentPos = Vector2(0, 0)
# Size of a single grid cell in pixels.
var grid_size = 32

# An array to represent directions: Right, Down, Left, Up.
var directions = [
	Vector2(1, 0), # Right
	Vector2(0, 1), # Down
	Vector2(-1, 0), # Left
	Vector2(0, -1)  # Up
]
# The current facing direction.
var current_direction = 0

# The Timer node is essential for step-by-step execution.
@onready var execution_timer = $ExecutionTimer


# --- Interpreter and Execution Logic ---

# Called by the UI's `code_executed` signal. This is the main entry point.
func _on_hud_code_executed(code_text: String) -> void:
	# Stop any running execution before starting a new one.
	stop_execution()
	command_queue.clear()
	
	# Split the input code into individual lines.
	var lines = code_text.split("\n", false)
	
	# Parse each line and add it to the command queue.
	for line in lines:
		var parsed_command = parse_command(line)
		if parsed_command:
			command_queue.append(parsed_command)
		else:
			print("Interpreter Error: Invalid command on line: " + line)
			# Stop parsing if an invalid command is found.
			command_queue.clear()
			return
	
	# Start execution if the queue is not empty.
	if not command_queue.is_empty():
		start_execution()

# Called by the Timer to execute the next command in the queue.
func _on_execution_timer_timeout():
	if not command_queue.is_empty():
		# Get the next command data from the front of the queue.
		var command_data = command_queue.pop_front()
		
		# Find the function to call based on the command name.
		var function_to_call = command_map[command_data.name]
		
		# Execute the function with its arguments.
		callv(function_to_call, command_data.args)
		
		# Restart the timer for the next command.
		execution_timer.start()
	else:
		# All commands have been executed.
		stop_execution()
		print("Execution finished!")


# --- Command Parsing ---

# Parses a single line of code into a command name and arguments.
func parse_command(line):
	var clean_line = line.strip_edges()
	if clean_line == "":
		return null
	
	var open_paren_pos = clean_line.find("(")
	var close_paren_pos = clean_line.find(")")
	
	# Handle commands with or without parentheses.
	if open_paren_pos == -1 or close_paren_pos == -1 or open_paren_pos > close_paren_pos:
		if command_map.has(clean_line):
			return { "name": clean_line, "args": [] }
		else:
			return null
	
	# Extract command name from the string.
	var command_name = clean_line.substr(0, open_paren_pos)
	
	if command_map.has(command_name):
		var command_data = { "name": command_name, "args": [] }
		
		# Extract arguments from inside the parentheses.
		var args_string = clean_line.substr(open_paren_pos + 1, close_paren_pos - (open_paren_pos + 1))
		var args = args_string.split(",", false)
		
		for arg in args:
			var arg_clean = arg.strip_edges()
			if arg_clean != "":
				# Convert the string argument to an integer.
				command_data.args.append(int(arg_clean))
		return command_data
	
	return null


# --- Control Functions ---

# Starts the interpreter's execution timer.
func start_execution():
	is_executing = true
	execution_timer.start()

# Stops the interpreter and resets the state.
func stop_execution():
	is_executing = false
	execution_timer.stop()


# --- Command Functions ---

# Moves the character one grid unit in its current facing direction.
func move_in_direction():
	var direction_vector = directions[current_direction]
	currentPos += direction_vector
	position = Vector2(currentPos.x * grid_size, currentPos.y * grid_size)
	print("Character moved!")
	
# Rotates the character's facing direction to the right.
func turn_right():
	current_direction = (current_direction + 1) % 4
	print("Character turned right!")

# Rotates the character's facing direction to the left.
func turn_left():
	current_direction = (current_direction - 1 + 4) % 4
	print("Character turned left!")
