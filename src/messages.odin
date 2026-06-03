package main

import eng "./engine"

// ─── Message panel layout ────────────────────────────────────────────────────

MSG_PANEL_Y :: i32(MAP_VIEW_HEIGHT)
MSG_PANEL_HEIGHT :: i32(MSG_REGION_HEIGHT)
MSG_FONT_SIZE :: i32(14)
MSG_LINE_HEIGHT :: i32(16)
MSG_MAX_VISIBLE :: 7

Message_Manager :: eng.Message_Manager

message_manager_make :: proc() -> Message_Manager {
	return eng.message_manager_make()
}

message_manager_bind_turns :: proc(messages: ^Message_Manager, turns: ^eng.Turn_Manager) {
	eng.message_manager_bind_turns(messages, turns)
}

// ─── Add a message to the ring buffer ────────────────────────────────────────

add_message :: proc(
	messages: ^Message_Manager,
	game: ^Game,
	text: string,
	color: eng.Engine_Color,
) {
	if messages == nil || game == nil {
		return
	}
	eng.message_manager_add(messages, text, color)
}

// ─── Clear all messages ──────────────────────────────────────────────────────

clear_messages :: proc(messages: ^Message_Manager) {
	eng.message_manager_clear(messages)
}

// ─── Render message panel ────────────────────────────────────────────────────

render_messages_for_engine :: proc(engine: ^eng.Engine) {
	render_messages(engine, game_engine_message_manager(engine))
}

render_messages :: proc(engine: ^eng.Engine, messages: ^Message_Manager) {
	if messages == nil {
		return
	}
	log := &messages.log

	// Draw dark background for the message panel
	eng.engine_render_draw_rectangle(
		engine,
		0,
		MSG_PANEL_Y,
		i32(SCREEN_WIDTH),
		MSG_PANEL_HEIGHT,
		eng.engine_color_make(15, 15, 20, 255),
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
		eng.engine_render_draw_text(engine, text_cstr, 8, y, MSG_FONT_SIZE, msg.color)
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
