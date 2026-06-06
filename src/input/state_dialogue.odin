package gameinput

import gp "../gameplay"
import eng "../engine"

// update_viewing_dialogue advances NPC dialogue. Confirm/continue steps to the
// next line; ESC ends the conversation (applying any quest effect on the way out).
update_viewing_dialogue :: proc(engine: ^eng.Engine, game: ^Game, im: ^Input_Manager) {
	messages := game_engine_message_manager(engine)

	if action_pressed(im, .Menu_Back) {
		gp.close_dialogue(game)
		return
	}

	if action_pressed(im, .Menu_Confirm) ||
	   action_pressed(im, .Pickup) ||
	   action_pressed(im, .Wait) {
		gp.advance_dialogue(messages, game)
	}
}
