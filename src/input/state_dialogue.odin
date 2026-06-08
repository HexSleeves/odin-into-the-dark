package gameinput

import gcore "../core"
import eng "../engine"
import gp "../gameplay"

update_viewing_dialogue :: proc(engine: ^eng.Engine, game: ^Game, im: ^Input_Manager) {
	content := game_engine_content_manager(engine)
	messages := game_engine_message_manager(engine)

	if action_pressed(im, .Menu_Back) {
		gp.close_dialogue(game)
		return
	}

	node, ok := gcore.dialogue_current_node(content, game)
	if !ok {
		gp.close_dialogue(game)
		return
	}

	if len(node.choices) > 0 {
		if action_pressed(im, .Menu_Up) {
			game.dialogue_choice = max(0, game.dialogue_choice - 1)
		}
		if action_pressed(im, .Menu_Down) {
			game.dialogue_choice = min(len(node.choices) - 1, game.dialogue_choice + 1)
		}
		if action_pressed(im, .Menu_Confirm) {
			gp.confirm_dialogue_choice(messages, content, game)
		}
	} else {
		if action_pressed(im, .Menu_Confirm) ||
		   action_pressed(im, .Pickup) ||
		   action_pressed(im, .Wait) {
			gp.advance_dialogue(messages, content, game)
		}
	}
}
