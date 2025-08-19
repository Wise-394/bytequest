extends Area2D

# --- Node References ---
@onready var execution_timer = $ExecutionTimer

# --- Core Interpreter Data ---
var command_map = {
	"move": "move_in_direction",
	"turn_left": "turn_left",
	"turn_right": "turn_right"
}

var command_queue = []
var pc = 0 # The Program Counter
var call_stack = [] # The new call stack
var is_executing = false

# --- Character State ---
var current_grid_pos = Vector2.ZERO
var grid_size = 32
var directions = [
	Vector2(1, 0), # Right
	Vector2(0, 1), # Down
	Vector2(-1, 0), # Left
	Vector2(0, -1) # Up
]
var current_direction_index = 0

# --- Entry Point ---
func _on_hud_code_executed(code_text: String) -> void:
	stop_execution()
	var parsed_commands = parse_code(code_text)
	if not parsed_commands.is_empty():
		command_queue = parsed_commands
		start_execution()

# --- Parsing ---
func parse_code(code_text: String) -> Array:
	var queue_to_parse = []
	var parsing_stack = []
	var lines = code_text.split("\n", false)

	for line in lines:
		var parsed_command = parse_single_line(line)
		if parsed_command == null:
			print("Interpreter Error: Invalid command on line: " + line)
			return []

		var cmd_name = parsed_command["name"]

		if cmd_name == "for":
			parsing_stack.append({ "count": parsed_command["args"][0], "body": [] })
		elif cmd_name == "end_loop":
			if parsing_stack.is_empty():
				print("Interpreter Error: 'end_loop' without matching 'for'")
				return []
			var loop = parsing_stack.pop_back()
			var loop_command = { "name": "loop", "args": [loop["count"], loop["body"]] }
			if not parsing_stack.is_empty():
				parsing_stack.back()["body"].append(loop_command)
			else:
				queue_to_parse.append(loop_command)
		else:
			if not parsing_stack.is_empty():
				parsing_stack.back()["body"].append(parsed_command)
			else:
				queue_to_parse.append(parsed_command)

	if not parsing_stack.is_empty():
		print("Interpreter Error: Mismatched 'for' and 'end_loop'")
		return []

	return queue_to_parse

func parse_single_line(line: String):
	var clean_line = line.strip_edges()
	if clean_line.is_empty():
		return { "name": "noop", "args": [] }

	var open_paren_pos = clean_line.find("(")
	if open_paren_pos == -1:
		if command_map.has(clean_line) or clean_line == "end_loop":
			return { "name": clean_line, "args": [] }
		return null

	var close_paren_pos = clean_line.find(")")
	if close_paren_pos == -1 or close_paren_pos < open_paren_pos:
		print("Error: Mismatched parentheses.")
		return null

	var command_name = clean_line.substr(0, open_paren_pos)
	var args_string = clean_line.substr(open_paren_pos + 1, close_paren_pos - (open_paren_pos + 1)).strip_edges()

	var args = []
	if not args_string.is_empty():
		var arg_parts = args_string.split(",", false)
		for arg in arg_parts:
			var arg_clean = arg.strip_edges()
			if not arg_clean.is_empty():
				if not arg_clean.is_valid_int():
					print("Error: Arguments must be integers.")
					return null
				args.append(int(arg_clean))

	if command_name == "for" and args.size() != 1:
		print("Error: 'for' expects exactly one argument")
		return null

	if command_map.has(command_name) or command_name == "for":
		return { "name": command_name, "args": args }
	if command_name == "end_loop":
		return { "name": "end_loop", "args": [] }

	return null

# --- Execution ---
func _on_execution_timer_timeout():
	if not is_executing:
		return
	
	# Handle end of the current frame
	var current_commands = command_queue
	if not call_stack.is_empty():
		var current_frame = call_stack.back()
		current_commands = current_frame.body

		if pc >= current_commands.size():
			if current_frame.frame_type == "loop":
				current_frame.remaining_count -= 1
				if current_frame.remaining_count > 0:
					pc = 0 # Loop another time
				else:
					call_stack.pop_back() # Loop is finished
					if not call_stack.is_empty():
						var parent_frame = call_stack.back()
						pc = parent_frame.return_pc + 1
					else:
						pc = current_frame.return_pc + 1
			
			if not is_executing:
				return
			
			execution_timer.start()
			return
		
	# Handle end of main program
	if call_stack.is_empty() and pc >= command_queue.size():
		stop_execution()
		return
		
	var command_data = current_commands[pc]
	var cmd_name = command_data["name"]
	var cmd_args = command_data["args"]

	if cmd_name == "noop":
		pc += 1
	elif cmd_name == "loop":
		start_new_loop(cmd_args, pc)
		pc = 0 # Reset PC to start of the loop body.
	else:
		execute_command(cmd_name, cmd_args)
		pc += 1
	
	execution_timer.start()

func start_new_loop(loop_args: Array, return_pc: int):
	var loop_count = loop_args[0]
	var loop_body = loop_args[1].duplicate(true)
	
	# Push a new execution frame onto the stack
	call_stack.append({
		"frame_type": "loop",
		"remaining_count": loop_count,
		"body": loop_body,
		"return_pc": return_pc
	})

func execute_command(cmd_name: String, cmd_args: Array):
	var function_to_call = command_map.get(cmd_name)
	if function_to_call:
		if cmd_args.is_empty():
			call(function_to_call)
		else:
			callv(function_to_call, cmd_args)
	else:
		print("Interpreter Error: Unknown command:", cmd_name)

func start_execution():
	is_executing = true
	pc = 0
	call_stack.clear()
	execution_timer.start()

func stop_execution():
	is_executing = false
	execution_timer.stop()
	command_queue.clear()
	pc = 0
	call_stack.clear()
	print("Execution finished!")

# --- Command Functions ---
func move_in_direction():
	var direction_vector = directions[current_direction_index]
	current_grid_pos += direction_vector
	position = current_grid_pos * grid_size
	print("Character moved to: ", current_grid_pos)

func turn_right():
	current_direction_index = (current_direction_index + 1) % 4
	print("Character turned right!")

func turn_left():
	current_direction_index = (current_direction_index - 1 + 4) % 4
	print("Character turned left!")
