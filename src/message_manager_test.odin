#+build !js
package main

import eng "./engine"
import "core:testing"

@(test)
message_manager_make_starts_empty :: proc(t: ^testing.T) {
	messages := message_manager_make()
	engine_messages: eng.Message_Manager = messages

	testing.expect_value(t, messages.log.count, 0)
	testing.expect_value(t, messages.log.head, 0)
	testing.expect_value(t, engine_messages.log.count, 0)
}

@(test)
message_manager_adds_and_clears_messages :: proc(t: ^testing.T) {
	messages := message_manager_make()
	turns := eng.turn_manager_make()
	game: Game
	eng.turn_manager_set(&turns, 7)
	message_manager_bind_turns(&messages, &turns)

	add_message(&messages, &game, "hello", eng.Engine_Color{255, 255, 255, 255})
	testing.expect_value(t, messages.log.count, 1)
	testing.expect_value(t, messages.log.messages[0].turn, 7)

	clear_messages(&messages)
	testing.expect_value(t, messages.log.count, 0)
	testing.expect_value(t, messages.log.head, 0)
}

@(test)
message_handlers_accept_manager_context :: proc(t: ^testing.T) {
	bind_handler: proc(messages: ^Message_Manager, turns: ^eng.Turn_Manager) =
		message_manager_bind_turns
	add_handler: proc(
			messages: ^Message_Manager,
			game: ^Game,
			text: string,
			color: eng.Engine_Color,
		) =
		add_message
	clear_handler: proc(messages: ^Message_Manager) = clear_messages
	render_handler: proc(engine: ^eng.Engine, messages: ^Message_Manager) = render_messages

	testing.expect(t, bind_handler != nil)
	testing.expect(t, add_handler != nil)
	testing.expect(t, clear_handler != nil)
	testing.expect(t, render_handler != nil)
}

@(test)
message_manager_fits_engine_service_storage :: proc(t: ^testing.T) {
	testing.expect(t, size_of(Message_Manager) <= eng.ENGINE_SERVICE_STORAGE_BYTES)
}