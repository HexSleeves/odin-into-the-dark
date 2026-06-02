package main

import rl "vendor:raylib"
import eng "./engine"

// ─── Message panel layout ────────────────────────────────────────────────────

MSG_PANEL_Y :: i32(MAP_VIEW_HEIGHT + HUD_REGION_HEIGHT)
MSG_PANEL_HEIGHT :: i32(MSG_REGION_HEIGHT)
MSG_FONT_SIZE :: i32(14)
MSG_LINE_HEIGHT :: i32(16)
MSG_MAX_VISIBLE :: 7

Message_Manager :: struct {
	log:   MessageLog,
	turns: ^eng.Turn_Manager,
}

message_manager_make :: proc() -> Message_Manager {
	return Message_Manager{}
}

message_manager_bind_turns :: proc(messages: ^Message_Manager, turns: ^eng.Turn_Manager) {
	if messages == nil {
		return
	}
	messages.turns = turns
}

// ─── Add a message to the ring buffer ────────────────────────────────────────

add_message :: proc(messages: ^Message_Manager, game: ^Game, text: string, color: rl.Color) {
	if messages == nil || game == nil {
		return
	}
	log := &messages.log

	// Write into the slot at head
	msg := &log.messages[log.head]
	msg.color = color
	msg.turn = eng.turn_manager_current(messages.turns)

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

clear_messages :: proc(messages: ^Message_Manager) {
	if messages == nil {
		return
	}
	messages.log.head = 0
	messages.log.count = 0
}

// ─── Render message panel ────────────────────────────────────────────────────

render_messages_for_engine :: proc(engine: ^eng.Engine) {
	render_messages(game_engine_message_manager(engine))
}

render_messages :: proc(messages: ^Message_Manager) {
	if messages == nil {
		return
	}
	log := &messages.log

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

// ─── Name helpers (data-driven) ──────────────────────────────────────────────

// Get display name for an enemy (uses .name field populated from data)
enemy_display_name :: proc(enemy: ^Enemy) -> string {
	if len(enemy.name) > 0 {return enemy.name}
	if len(enemy.enemy_type) > 0 {return enemy.enemy_type}
	return "Unknown"
}

// Get display name for an item (uses .name field populated from data)
item_display_name :: proc(item: ^Item) -> string {
	if len(item.name) > 0 {return item.name}
	if len(item.item_type) > 0 {return item.item_type}
	return "Unknown"
}
