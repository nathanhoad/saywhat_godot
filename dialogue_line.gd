class_name DialogueLine
extends Object


var type: String
var character: String
var dialogue: String
var mutation: String
var options : Array = []
var next_node_id: String


# Check to see if we need to show a list of options
func has_options() -> bool:
	return options.size() > 1


# Run the mutation
func mutate() -> void:
	yield(DialogueManager.mutate(mutation), "completed")
