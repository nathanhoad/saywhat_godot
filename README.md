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

When initialising you provide it with state objects. These objects will be used (along with the current scene) for running conditional line checks and performing state mutations.

```gdscript
# Basic nodes that contains game state and methods for affecting state
DialogueManager.game_states = [SessionState, GameState]
```

### Example project

Check out <https://github.com/nathanhoad/saywhat_godot_example> to see a quick example of how the dialogue manager can be used to show dialogue on the screen (and handle mutations).

### Getting dialogue

The easiest way of getting a line of dialogue to display is by yielding to `get_next_dialogue_line` using an ID that you can copy from the SayWhat dialogue editor:

```gdscript
var dialogue_resource = preload("res://assets/dialogue/example.tres")
var dialogue = yield(DialogueManager.get_next_dialogue_line(id, dialogue_resource), "completed")
```

This will find the line with the given `id` and then begin checking conditions and stepping over each line in the `next_id` sequence until we hit a line of dialogue that can be displayed (or the end of the conversation). Any mutations found along the way will be exectued as well.

The returned line in `dialogue` will have the following properties:

- **character**: String
- **dialogue**: String
- **next_id**: String
- **responses**: Array of DialogueOptions:
  - **prompt**: String
  - **next_id**: String

It's up to you to implement the actual dialogue rendering and input control.

I have a `DialogueBalloon` scene that I instance that handles all of the rendering and user input:

```gdscript
# Show a line of dialogue from a given ID from SayWhat
func show_dialogue(id: String, resource: DialogueResource) -> void:
	var dialogue = yield(DialogueManager.get_next_dialogue_line(id, resource), "completed")
	if dialogue != null:
		var balloon := DialogueBalloon.instance()
		balloon.dialogue = dialogue
		add_child(balloon)
		# Dialogue might have response options so we have to wait and see
		# what the player chose
		show_dialogue(yield(balloon, "dialogue_actioned"), resource)
```

### Conditions

Conditions let you optionally show dialogue or response options.

If you have a condition in the dialogue editor like `if some_variable == 1` or `if some_other_variable` then you need to have a matching property on one of the given `game_state`s or the current scene.

If you have a condition like `if has_item("rubber_chicken")` then you will need a method on one of the `game_state`s or the current scene that matches the signature `func has_item(thing: String) -> bool:` (where the argument `thing` can be called whatever you want, as long as the type matches or is untyped). The method will be given `"rubber_chicken"` as that argument).

### Mutations

Mutations are for updating game state or running sequences (or both).

If you have a mutation in the dialogue editor like `do some_variable = 1` then you will need a matching property on one of your `game_state`s or the current scene.

If you have a mutation like `do animate("Character", "cheer")` then you will need a method on one of the `game_state`s or the current scene that matches the signature `func animate(character: String, animation: String) -> void:`. The argument `character` will be given `"Character"` and `animation` will be given `"cheer"`.

### Translations

By default, all dialogue and response prompts will be run through Godot's `tr` function to provide translations. 

You can turn this off by setting `DialogueManager.auto_translate = false` but beware, if it is off you may need to handle your own variable replacements if using manual translation keys. You can use `DialogueManager.replace_values(line)` or `DialogueManager.replace_values(response)` to replace text variable markers with their values.

## Contributors

[Nathan Hoad](https://nathanhoad.net)

## License

Licensed under the MIT license, see `LICENSE.md` for more information.
