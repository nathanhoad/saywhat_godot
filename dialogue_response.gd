extends Node


var prompt: String
var next_id: String


func _init(data: Dictionary) -> void:
	prompt = data.get("text")
	next_id = data.get("next_id")
