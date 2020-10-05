class_name DialogueLine
extends Object


var type: String
var character: String
var dialogue: String
var mutation: String
var options : Array = []
var next_node_id: String


func has_options() -> bool:
	return options.size() > 1
