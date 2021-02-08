extends Node


signal dialogue_started
signal dialogue_finished


const TYPE_DIALOGUE = "dialogue"
const TYPE_MUTATION = "mutation"
const TYPE_RESPONSES = "responses"
const TYPE_GOTO = "goto"


var resource : DialogueResource
var game_state : Node

var is_dialogue_running := false setget set_is_dialogue_running


func get_line(key: String) -> DialogueLine:
	assert(resource != null)

	var dialogue = resource.lines.get(key)
	
	if dialogue == null:
		return null
	
	# Skip over nodes that fail their condition
	if not check(dialogue.get("condition", "")):
		return get_line(dialogue.get("next_node_id"))
	
	# Evaluate early exits
	if dialogue.get("type") == TYPE_GOTO and check(dialogue.get("condition", "")):
		return get_line(dialogue.get("go_to_node_id", ""))
	
	# No dialogue and only one node is the same as an early exit
	if dialogue.get("type") == TYPE_RESPONSES:
		var responses = extract_responses(dialogue)
		if responses.size() == 1:
			return get_line(responses[0].next_node_id)
	
	# Set up a line object
	var line = DialogueLine.new()
	line.type = dialogue.get("type", TYPE_DIALOGUE)
	line.character = dialogue.get("character", "")
	line.dialogue = dialogue.get("dialogue", "")
	line.mutation = dialogue.get("mutation", "")
	line.next_node_id = dialogue.get("next_node_id", "")
	
	# Inject the next node's responses if they have any
	var next_dialogue = resource.lines.get(dialogue.get("next_node_id"))
	line.responses = extract_responses(next_dialogue)
	
	# If there is only one response then it has to point to the next node
	if line.responses.size() == 1:
		line.next_node_id = line.responses[0].next_node_id
		
	return line


# Get a list of valid responses from a dialogue node
func extract_responses(dialogue: Dictionary) -> Array:
	var responses : Array = []
	if dialogue != null and dialogue.get("type") == TYPE_RESPONSES:
		for o in dialogue.get("responses"):
			if check(o.get("condition", "")):
				var response = DialogueResponse.new()
				response.prompt = o.get("prompt")
				response.next_node_id = o.get("next_node_id", "")
				responses.append(response)
	return responses


# Step through lines and run any mutations until we either 
# hit some dialogue or the end of the conversation
func get_next_dialogue_line(key: String) -> DialogueLine:
	var dialogue = get_line(key)
	
	yield(get_tree(), "idle_frame")
	
	self.is_dialogue_running = true
	
	# If our dialogue is nothing then we hit the end
	if dialogue == null or not is_valid(dialogue):
		self.is_dialogue_running = false
		return null
	
	# Run the mutation if it is one
	if dialogue.type == TYPE_MUTATION:
		yield(mutate(dialogue.mutation), "completed")
		if dialogue.next_node_id != "":
			return get_next_dialogue_line(dialogue.next_node_id)
		else:
			# End the conversation
			self.is_dialogue_running = false
			return null
	else:
		return dialogue


func set_is_dialogue_running(value: bool) -> void:
	if is_dialogue_running != value:
		if value:
			emit_signal("dialogue_started")
		else:
			emit_signal("dialogue_finished")
			
	is_dialogue_running = value


# Check if a condition is met
func check(condition: String) -> bool:
	if condition == "":
		return true
	
	var regex : = RegEx.new()
	regex.compile("^(?<negate>\\!)?(?<key>[a-zA-Z_]+[a-zA-Z_0-9]+)\\s?(?<op>=|==|<|>|<=|>=|!=|<>)?\\s?(?<value>.*)?$")
	var found = regex.search(condition)
	
	var key : String = found.strings[found.names.get("key")]
	var state_value
	
	var current_scene = get_tree().current_scene
	
	if is_method(current_scene, key):
		var parts = Array(condition.split(" "))
		var args = parts.slice(1, parts.size() - 1)
		return current_scene.call(key, args)
	elif is_method(game_state, key):
		var parts = Array(condition.split(" "))
		var args = parts.slice(1, parts.size() - 1)
		return game_state.call(key, args)
	elif is_property(game_state, key):
		state_value = game_state.get(key)
	elif is_property(current_scene, key):
		state_value = current_scene.get(key)
	else:
		assert(false, "'" + key +  "' is not a method or a property on game state or the current scene.")
	
	# Simple checks like "is_thing" and "!is_thing"
	if found.names.has("negate"):
		return bool(state_value) == false
	if not " " in condition and not "=" in condition:
		return bool(state_value)
	
	# More complicated checks
	var value = match_type(found.strings[found.names.get("value")], typeof(state_value))
	var operator : String = found.strings[found.names.get("op")]
	match operator:
		"":
			return call(key, String(value).split(" "))
		
		"=", "==":
			return state_value == value
		
		"<":
			return state_value < value
		
		"<=":
			return state_value <= value
		
		">":
			return state_value > value
		
		">=":
			return state_value >= value
		
		"!=", "<>":
			return state_value != value
	
	return false


# Make a change to game state or run a method
func mutate(mutation: String) -> void:
	if "=" in mutation:
		var regex := RegEx.new()
		regex.compile("^(?<key>[a-zA-Z_]+[a-zA-Z_0-9]+)\\s?(?<op>=|\\+=|\\-=)?\\s?(?<value>.*)?$")
		var found = regex.search(mutation)
		
		var key : String = found.strings[found.names.get("key")]
		var operator : String = found.strings[found.names.get("op")]
		
		var current_value = game_state.get(key)
		var value = match_type(found.strings[found.names.get("value")], typeof(current_value))
		
		match operator:
			"=":
				game_state.set(key, value)
			
			"+=":
				game_state.set(key, current_value + value)
				
			"-=":
				game_state.set(key, current_value - value)
		
	else:
		var parts = Array(mutation.split(" "))
		var key = parts[0]
		var args = parts.slice(1, parts.size() - 1)
		
		var scene = get_tree().current_scene
		
		# Built in wait mutation
		if key == "wait":
			yield(get_tree().create_timer(float(args[0])), "timeout")
			
		# Otherwise check for defined mutations
		elif is_method(game_state, key):
			var result = game_state.call(key, args)
			if result is GDScriptFunctionState and result.is_valid():
				yield(result, "completed")
				
		elif is_method(scene, key):
			var result = scene.call(key, args)
			if result is GDScriptFunctionState and result.is_valid():
				yield(result, "completed")
		
		# Or fail with a hint of what's wrong
		else:
			assert(false, "'" + key +  "' mutation method not found on game state or current scene")
	
	# Wait one frame to give the dialogue handler a chance to yield
	yield(get_tree(), "idle_frame")


# Make sure a value is a given type
func match_type(value, type):
	match type:
		TYPE_BOOL:
			if value.to_lower() == "false":
				return false
			if value.to_lower() == "true":
				return true
			return bool(value)
		
		TYPE_STRING:
			return String(value)
		
		TYPE_INT:
			return int(value)
		
		TYPE_REAL:
			return float(value)


# Check if a dialogue line contains meaninful information
func is_valid(line: DialogueLine) -> bool:
	if line.type == "":
		return false
	if line.type == TYPE_DIALOGUE and line.dialogue == "":
		return false
	if line.type == TYPE_MUTATION and line.mutation == "":
		return false
	if line.type == TYPE_RESPONSES and line.responses.size() == 0:
		return false
	return true


# Check if a given property exists
func is_property(thing: Object, name: String) -> bool:
	if thing == null:
		return false
	
	for p in thing.get_property_list():
		if p.name == name:
			return true
	return false
		

# Check if a given method exists
func is_method(thing: Object, name: String) -> bool:
	if thing == null:
		return false

	for m in thing.get_method_list():
		if m.name == name:
			return true
	return false
