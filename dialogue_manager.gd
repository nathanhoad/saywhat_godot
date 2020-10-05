extends Node


const TYPE_DIALOGUE = "dialogue"
const TYPE_MUTATION = "mutation"
const TYPE_OPTIONS = "options"


var resource : DialogueResource
var game_state : Node


func get_line(key: String) -> DialogueLine:
	assert(resource != null)

	var dialogue = resource.lines.get(key)
	
	if dialogue == null:
		return null
	
	# Skip over nodes that fail their condition
	if not check(dialogue.get("condition", "")):
		return get_line(dialogue.get("next_node_id"))
	
	# Set up a line object
	var line = DialogueLine.new()
	line.type = dialogue.get("type", TYPE_DIALOGUE)
	line.character = dialogue.get("character", "")
	line.dialogue = dialogue.get("dialogue", "")
	line.mutation = dialogue.get("mutation", "")
	line.next_node_id = dialogue.get("next_node_id", "")
	
	# Inject the next node's options if they have any
	var next_dialogue = resource.lines.get(dialogue.get("next_node_id"))
	if next_dialogue != null and next_dialogue.get("type") == TYPE_OPTIONS:
		var next_index := 0
		for o in next_dialogue.get("options"):
			if check(o.get("condition", "")):
				var option = DialogueOption.new()
				option.index = next_index
				option.prompt = o.get("prompt")
				option.next_node_id = o.get("next_node_id", "")
				line.options.append(option)
				next_index += 1
		
	return line



# Check if a condition is met
func check(condition: String) -> bool:
	if condition == "":
		return true
	
	var regex : = RegEx.new()
	regex.compile("^(?<negate>\\!)?(?<key>[a-zA-Z_]+[a-zA-Z_0-9]+)\\s?(?<op>=|==|<|>|<=|>=|!=|<>)?\\s?(?<value>.*)?$")
	var found = regex.search(condition)
	
	var key : String = found.strings[found.names.get("key")]
	var state_value
	
	if is_method(game_state, key):
		state_value = game_state.call(key)
	elif is_method(get_tree().current_scene, key):
		state_value = get_tree().current_scene.call(key)
	else:
		state_value = game_state.get(key)
	
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
		if is_method(game_state, key):
			var result = game_state.call(key, args)
			if result is GDScriptFunctionState and result.is_valid():
				yield(result, "completed")
		elif is_method(scene, key):
			var result = scene.call(key, args)
			if result is GDScriptFunctionState and result.is_valid():
				yield(result, "completed")
	
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


# Check if a given method exists
func is_method(thing: Object, name: String) -> bool:
	if thing == null:
		return false

	for m in thing.get_method_list():
		if m.name == name:
			return true
	return false
