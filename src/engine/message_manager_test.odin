package engine

import "core:testing"

@(test)
engine_message_manager_starts_empty_and_binds_turns :: proc(t: ^testing.T) {
	messages := message_manager_make()
	turns := turn_manager_make()
	turn_manager_set(&turns, 12)
	message_manager_bind_turns(&messages, &turns)

	testing.expect_value(t, messages.log.count, 0)
	testing.expect_value(t, messages.log.head, 0)
	testing.expect(t, messages.turns == &turns)
}

@(test)
engine_message_manager_adds_turn_stamped_colored_messages :: proc(t: ^testing.T) {
	messages := message_manager_make()
	turns := turn_manager_make()
	turn_manager_set(&turns, 7)
	message_manager_bind_turns(&messages, &turns)

	message_manager_add(&messages, "hello", engine_color_make(1, 2, 3, 4))

	msg := &messages.log.messages[0]
	testing.expect_value(t, messages.log.count, 1)
	testing.expect_value(t, messages.log.head, 1)
	testing.expect_value(t, msg.turn, 7)
	testing.expect_value(t, msg.color.r, u8(1))
	testing.expect_value(t, msg.color.g, u8(2))
	testing.expect_value(t, msg.color.b, u8(3))
	testing.expect_value(t, msg.color.a, u8(4))
	testing.expect_value(t, msg.text_len, 5)
	testing.expect_value(t, msg.text[0], u8('h'))
	testing.expect_value(t, msg.text[4], u8('o'))
	testing.expect_value(t, msg.text[5], u8(0))
}

@(test)
engine_message_manager_wraps_at_capacity_and_clears :: proc(t: ^testing.T) {
	messages := message_manager_make()

	for i in 0 ..< ENGINE_MAX_MESSAGES + 2 {
		message_manager_add(&messages, "x", engine_color_make(u8(i), 0, 0, 255))
	}

	testing.expect_value(t, messages.log.count, ENGINE_MAX_MESSAGES)
	testing.expect_value(t, messages.log.head, 2)
	testing.expect_value(t, messages.log.messages[0].color.r, u8(ENGINE_MAX_MESSAGES))
	testing.expect_value(t, messages.log.messages[1].color.r, u8(ENGINE_MAX_MESSAGES + 1))

	message_manager_clear(&messages)
	testing.expect_value(t, messages.log.count, 0)
	testing.expect_value(t, messages.log.head, 0)
}
