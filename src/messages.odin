package main

import rl "vendor:raylib"

// ─── Message panel layout ────────────────────────────────────────────────────

MSG_PANEL_Y :: i32(MAP_VIEW_HEIGHT + HUD_REGION_HEIGHT)
MSG_PANEL_HEIGHT :: i32(MSG_REGION_HEIGHT)
MSG_FONT_SIZE :: i32(14)
MSG_LINE_HEIGHT :: i32(16)
MSG_MAX_VISIBLE :: 7

// ─── Add a message to the ring buffer ────────────────────────────────────────

add_message :: proc(game: ^Game, text: string, color: rl.Color) {
	log := &game.message_log

	// Write into the slot at head
	msg := &log.messages[log.head]
	msg.color = color
	msg.turn = game.turn_count

	// Copy text into fixed buffer (truncate if too long)
	n := min(len(text), MAX_MSG_LEN - 1)
	for i in 0 ..< n {
		msg.text[i] = text[i]
	}
	msg.text[n] = 0 // null-terminate
	msg.text_len = n

	// Advance head (ring buffer wrap)
	log.head = (log.head + 1) % MAX_MESSAGES
	if log.count < MAX_MESSAGES {
		log.count += 1
	}
}

// ─── Clear all messages ──────────────────────────────────────────────────────

clear_messages :: proc(game: ^Game) {
	game.message_log.head = 0
	game.message_log.count = 0
}

// ─── Render message panel ────────────────────────────────────────────────────

render_messages :: proc(game: ^Game) {
	log := &game.message_log

	// Draw dark background for the message panel
	rl.DrawRectangle(
		0,
		MSG_PANEL_Y,
		i32(SCREEN_WIDTH),
		MSG_PANEL_HEIGHT,
		rl.Color{15, 15, 20, 255},
	)

	// Determine how many messages to show
	visible_count := min(log.count, MSG_MAX_VISIBLE)
	if visible_count == 0 {
		return
	}

	// Draw messages newest-at-bottom
	// The newest message is at index (head - 1), second newest at (head - 2), etc.
	for i in 0 ..< visible_count {
		// Message index: from oldest visible to newest
		// i=0 is the oldest visible, i=visible_count-1 is the newest
		msg_offset := visible_count - 1 - i
		msg_idx := (log.head - 1 - msg_offset + MAX_MESSAGES * 2) % MAX_MESSAGES
		msg := &log.messages[msg_idx]

		y := MSG_PANEL_Y + 4 + i32(i) * MSG_LINE_HEIGHT
		text_cstr := cast(cstring)&msg.text[0]
		rl.DrawText(text_cstr, 8, y, MSG_FONT_SIZE, msg.color)
	}
}

// ─── Enemy type name helper ──────────────────────────────────────────────────

enemy_type_name :: proc(etype: Enemy_Type) -> string {
	switch etype {
	case .Rat:
		return "Rat"
	case .Miner_Husk:
		return "Miner Husk"
	case .Cave_Crawler:
		return "Cave Crawler"
	case .Deep_Watcher:
		return "Deep Watcher"
	}
	return "Unknown"
}
