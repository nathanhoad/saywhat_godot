![SayWhat logo](assets/logo.svg)

# SayWhat addon for Godot

A branching dialogue manager for Godot. Used in conjunction with the [SayWhat branching dialogue editor](https://nathanhoad.itch.io/saywhat).

## Installation

1. Clone or download a copy of this repository.
2. Copy the contents into your `res://addons/saywhat_godot` directory.
3. Enable `SayWhat` in your project plugins.

## Usage

The SayWhat addon provides a global `DialogueManager` that you can use to get lines of dialogue.

### Initialising

When initialising you must provide it with a dialogue resource and and a state object (for running conditional line checks).

```gdscript
# An exported dialogue resource from the SayWhat editor
DialogueManager.resource = preload("res://text/dialogue.tres")
# A basic node that contains game state
DialogueManager.game_state = GameState
```

### Example project

Check out <https://github.com/nathanhoad/saywhat_godot_example> to see a quick example of how the dialogue manager can be used to show dialogue on the screen (and handle mutations).

### Getting dialogue

The easiest way of getting a line of dialogue to display is by yielding to `get_next_dialogue_line` using an ID that you can copy from the SayWhat dialogue editor:

```gdscript
var dialogue = yield(DialogueManager.get_next_dialogue_line(id), "completed")
```

This will find the line with the given `id` and then begin checking conditions and stepping over each line in the `next_node_id` sequence until we hit a line of dialogue that can be displayed (or the end of the conversation). Any mutations found along the way will be exectued as well.

The returned line in `dialogue` will have the following properties:

- **character**: String
- **dialogue**: String
- **next_node_id**: String
- **responses**: Array (DialogueOption):
  - **prompt**: String
  - **next_node_id**: String

It's up to you to implement the actual dialogue rendering and input control.

I have a `DialogueBalloon` scene that I instance that handles all of the rendering and user input:

```gdscript
# Show a line of dialogue from a given ID from SayWhat
func show_dialogue(id: String) -> void:
	var dialogue = yield(DialogueManager.get_next_dialogue_line(id), "completed")
	if dialogue != null:
		var balloon := DialogueBalloon.instance()
		balloon.dialogue = dialogue
		add_child(balloon)
		# Dialogue might have response options so we have to wait and see
		# what the player choose
		show_dialogue(yield(balloon, "dialogue_actioned"))
```

### Conditions

Conditions let you optionally show dialogue or response options.

If you have a condition in the dialogue editor like `[if some_variable == 1]` or `[if some_other_variable]` then you need to have a matching property on `game_state` or the current scene.

If you have a condition like `[if has_item rubber_chicken]` then you will need a method on `game_state` or the current scene that matches the signature `func has_item(args: Array) -> bool:` (where args will be given `["rubber_chicken"]`).

### Mutations

Mutations are for updating game state or running sequences (or both).

If you have a mutation in the dialogue editor like `[do some_variable = 1]` then you will need a matching property on your `game_state` or current scene.

If you have a mutation like `[do animate Character cheer]` then you will need a method on `game_state` or the current scene that matches the signature `func animate(args: Array) -> void:` (where `args` will be given `["Character", "cheer"]`).

## Contributors

[Nathan Hoad](https://nathanhoad.net)

## License

Licensed under the MIT license, see `LICENSE.md` for more information.
