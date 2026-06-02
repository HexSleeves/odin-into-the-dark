package engine

ENGINE_MAX_MESSAGES :: 64
ENGINE_MAX_MESSAGE_LEN :: 256

Message :: struct {
	text:     [ENGINE_MAX_MESSAGE_LEN]u8,
	text_len: int,
	color:    Engine_Color,
	turn:     int,
}

Message_Log :: struct {
	messages: [ENGINE_MAX_MESSAGES]Message,
	head:     int,
	count:    int,
}

Message_Manager :: struct {
	log:   Message_Log,
	turns: ^Turn_Manager,
}

message_manager_make :: proc() -> Message_Manager {
	return Message_Manager{}
}

message_manager_bind_turns :: proc(messages: ^Message_Manager, turns: ^Turn_Manager) {
	if messages == nil {
		return
	}
	messages.turns = turns
}

message_manager_add :: proc(messages: ^Message_Manager, text: string, color: Engine_Color) {
	if messages == nil {
		return
	}
	log := &messages.log
	msg := &log.messages[log.head]
	msg.color = color
	msg.turn = turn_manager_current(messages.turns)

	n := min(len(text), ENGINE_MAX_MESSAGE_LEN - 1)
	for i in 0 ..< n {
		msg.text[i] = text[i]
	}
	msg.text[n] = 0
	msg.text_len = n

	log.head = (log.head + 1) % ENGINE_MAX_MESSAGES
	if log.count < ENGINE_MAX_MESSAGES {
		log.count += 1
	}
}

message_manager_clear :: proc(messages: ^Message_Manager) {
	if messages == nil {
		return
	}
	messages.log.head = 0
	messages.log.count = 0
}

