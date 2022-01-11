tool
extends EditorPlugin


func _enter_tree():
	add_autoload_singleton("DialogueManager", "res://addons/saywhat_godot/dialogue_manager.gd")


func _exit_tree():
	remove_autoload_singleton("DialogueManager")
