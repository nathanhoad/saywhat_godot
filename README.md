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

If the line had a condition on it (eg. `some_variable == 42`) then the dialogue manager will check with the given `game_state` node to see
if `game_state.some_variable` has a value of 42. If it does it will return that line as a DialogueLine object, otherwise it will move on to that line's
`next_node_id` (and so on, until a line passes its condition).

If the next line after a valid line of dialogue is a response options list then that list will be filtered by each option's condition checks
and then grafted onto the line.

The returned line will have the following structure:

- **type**: String, "dialogue" or "mutation"
- **character**: String
- **dialogue**: String
- **mutation**: String
- **mutate()**: run the mutation
- **next_node_id**: String
- **options**: Array of DialogueOption:
  - **index**: int, index in the array after condition checks have removed failed options
  - **prompt**: String
  - **next_node_id**: String

### Mutations

Mutations are for updating game state or running sequences (or both).

When running mutations with `dialogue.mutate()` it is recommended to yield for "completed" so that it doesn't matter if the mutation is a simple function or a sequence with its own yields.

To implement a mutation in your game you just need a function on either the game state object or the current scene that matches the mutations name in your dialogue.

So, a mutation in the dialogue like `[do animate Player look_around]` would look for a function called `animate` and then run it with a single array arg, `["Player", "look_around"]`.

## Example

If the dictionary in our dialogue resource contained something like:

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

Then, assuming `GameState.some_variable != 42` and running `DialogueManager.get_line("first")` we would end up with this line:

```
type: "dialogue",
character: "Coco",
dialogue: "This dialogue will have a response options list added to it.",
options: [
  (
    prompt: "Ok",
    next_node_id: ""
  ), (
    prompt: "What about 42?",
    next_node_id: ""
  ), (
    prompt: "Start again",
    next_node_id: "first"
  )
]
```

Where the line with ID `first` is bypassed because it fails its condition check (whereas the response option passes its check so it gets included).

It's up to you to implement the actual dialogue rendering and input control by I have something like this (where rendering the dialogue and handling user input is done by my DialogueBalloon scene):

```gdscript
func show_dialogue(key: String, is_first_line: bool = true) -> void:
	var dialogue = DialogueManager.get_line(key)

	# Start conversation
	if is_first_line:
		emit_signal("dialogue_started")

	# Run the line
	var next_node_id = dialogue.next_node_id
	match dialogue.type:
		DialogueManager.TYPE_DIALOGUE:
			var balloon := DialogueBalloon.instance()
			balloon.dialogue = dialogue
			add_child(balloon)
			# The balloon might have response options so we have to get the
			# next node id from it once it's ready
			next_node_id = yield(balloon, "dialogue_actioned")

		DialogueManager.TYPE_MUTATION:
			yield(dialogue.mutate(), "completed")

	# End conversation
	if next_node_id == "":
		var camera := get_tree().current_scene.find_node("Camera")
		yield(camera.return_to_target(), "completed")
		emit_signal("dialogue_finished")

	# Next line
	else:
		show_dialogue(next_node_id, false)
```

## Contributors

[Nathan Hoad](https://nathanhoad.net)

## License

Licensed under the MIT license, see `LICENSE.md` for more information.
