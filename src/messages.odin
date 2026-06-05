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
	clay_render_messages(game_engine_message_manager(engine))
}

render_messages :: proc(engine: ^eng.Engine, messages: ^Message_Manager) {
	_ = engine
	clay_render_messages(messages)
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
