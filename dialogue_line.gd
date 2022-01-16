extends Node

const TYPE_CONDITION = "condition"
const TYPE_DIALOGUE = "dialogue"
const TYPE_MUTATION = "mutation"
const TYPE_RESPONSE = "response"
const TYPE_GOTO = "goto"

var type: String = TYPE_DIALOGUE
var next_id: String

var mutation: Dictionary

var character: String
var dialogue: String
var replacements: Array

var responses: Array = []


func _init(data: Dictionary, should_translate: bool = true) -> void:
	type = data.get("type")
	next_id = data.get("next_id")
	
	match data.get("type"):
		TYPE_DIALOGUE:
			character = data.get("character")
			dialogue = tr(data.get("text")) if should_translate else data.get("text")
			replacements = data.get("replacements")
			
		TYPE_MUTATION:
			mutation = data.get("mutation")
