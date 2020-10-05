![SayWhat logo](assets/logo.svg)

# SayWhat addon for Godot

A branching dialogue manager for Godot. Used in conjunction with the [SayWhat branching dialogue editor](https://nathanhoad.itch.io/saywhat).

## Installation

1. Clone or download a copy of this repository.
2. Copy the contents into your `res://addons/saywhat_godot` directory.
3. Enable `SayWhat` in your project plugins.

## Usage

The SayWhat addon provides a global `DialogueManager` that you can use to get lines of dialogue.

When initialising you must provide it with a dialogue resource and and a state object (for running conditional line checks).

```gdscript
# An exported dialogue resource from the SayWhat editor
DialogueManager.resource = preload("res://text/dialogue.tres")
# A basic node that contains game state
DialogueManager.game_state = GameState
```

Then you can get the dialogue from a given key (copied from the SayWhat editor):

```gdscript
var line : DialogueLine = DialogueManager.get_line("a1debbe0-e9ff-492c-bd54-7c2ffeac634c")
```

The returned line will have the following keys:

```
type: String, "dialogue" or "mutation"
character: String
dialogue: String
mutation: String
next_node_id: String
options : Array of DialogueOption
	var index: int, index in the array after condition checks have removed failed options
	var prompt: String
	var next_node_id: String
```

If the line has a condition on it (eg. `some_variable == 42`) then the dialogue manager will check with the given `game_state` node to see
if `game_state.some_variable` has a value of 42. If it does it will return that line as a dictionary, otherwise it will move on to that line's
`next_node_id` (and so on, until a line passes its condition).

If the next line after a valid line of dialogue is a response options list then that list will be filtered by each option's condition checks
and then grafted onto the line.

```
{
  id: "first",
  type: "dialogue",
  condition: "some_variable == 42",
  character: "Coco",
  dialogue: "This dialogue has a condition.",
  next_node_id: "second"
},
{
  id: "second",
  type: "dialogue",
  character: "Coco",
  dialogue: "This dialogue will have a response options list added to it.",
  next_node_id: "third"
},
{
  id: "third",
  type: "options",
  options: [
    {
      prompt: "Ok",
      next_node_id: ""
    },
    {
      prompt: "What about 42?",
      condition: "some_variable != 42",
      next_node_id: ""
    },
    {
      prompt: "Start again",
      next_node_id: "first"
    }
  ]
}
```

Assuming `GameState.some_variable != 42` and running `DialogueManager.get_line("first")` we would end up with this dictionary:

```
{
  id: "second",
  type: "dialogue",
  character: "Coco",
  dialogue: "This dialogue will have a response options list added to it.",
  options: [
    {
      prompt: "Ok",
      next_node_id: ""
    },
    {
      prompt: "What about 42?",
      condition: "some_variable != 42",
      next_node_id: ""
    },
    {
      prompt: "Start again",
      next_node_id: "first"
    }
  ]
}
```

Where the line with ID `first` is bypassed because it fails its condition check (whereas the response option passes its check so it gets included).

It's up to you to implement the actual dialogue rendering and input control by I have something like this (where rendering the dialogue and handling user input is done by my DialogueBalloon scene):

```gdscript
func show_dialogue(key: String) -> void:
	var dialogue = DialogueManager.get_line(key)

	# End conversation
	if dialogue == null:
		var camera := get_tree().current_scene.find_node("Camera")
		yield(camera.return_to_target(), "completed")
		dialogue_is_showing = false
		emit_signal("dialogue_finished")
		return

	# Start conversation
	if not dialogue_is_showing:
		dialogue_is_showing = true
		emit_signal("dialogue_started")

	# Run the line
	var next_node_id = ""
	match dialogue.type:
		DialogueManager.TYPE_DIALOGUE:
			var balloon := DialogueBalloon.instance()
			balloon.dialogue = dialogue
			add_child(balloon)
			# The balloon might have response options so we have to get the
			# next node id from it once it's ready
			next_node_id = yield(balloon, "dialogue_next")

		DialogueManager.TYPE_MUTATION:
			yield(DialogueManager.mutate(dialogue.mutation), "completed")
			# Mutations only have one next_node_id
			next_node_id = dialogue.next_node_id

	show_dialogue(next_node_id)
```

## Contributors

[Nathan Hoad](https://nathanhoad.net)

## License

Licensed under the MIT license, see `LICENSE.md` for more information.
