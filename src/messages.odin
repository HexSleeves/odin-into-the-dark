package main

import eng "./engine"


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
