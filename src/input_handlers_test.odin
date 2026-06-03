#+build !js
package main

import eng "./engine"
import "core:testing"

@(test)
input_handlers_accept_engine_context_for_services :: proc(t: ^testing.T) {
	title_handler: proc(engine: ^eng.Engine, game: ^Game, im: ^Input_Manager) -> bool =
		update_title_screen
	choice_handler: proc(engine: ^eng.Engine, game: ^Game) -> bool = activate_title_choice
	global_handler: proc(engine: ^eng.Engine, game: ^Game, im: ^Input_Manager) =
		handle_global_input
	playing_handler: proc(engine: ^eng.Engine, game: ^Game, im: ^Input_Manager) -> bool =
		update_playing

	testing.expect(t, title_handler != nil)
	testing.expect(t, choice_handler != nil)
	testing.expect(t, global_handler != nil)
	testing.expect(t, playing_handler != nil)
}
