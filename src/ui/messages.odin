package ui

import gcore "../core"
import eng "../engine"

Message_Manager :: eng.Message_Manager
message_manager_make :: eng.message_manager_make
message_manager_bind_turns :: eng.message_manager_bind_turns

add_message :: proc(
	messages: ^Message_Manager,
	game: ^gcore.Game,
	text: string,
	color: eng.Engine_Color,
) {
	if messages == nil || game == nil {return}
	eng.message_manager_add(messages, text, color)
}

clear_messages :: proc(messages: ^Message_Manager) {
	eng.message_manager_clear(messages)
}
