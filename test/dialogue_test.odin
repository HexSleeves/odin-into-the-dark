#+build !js
package main

import eng "./engine"
import "core:testing"


// ─── dialogue_select_conv ────────────────────────────────────────────────────

@(test)
dialogue_select_conv_picks_highest_priority_matching_conversation :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)

	// Quest Not_Started: old_miner_intro (priority 10) should win over old_miner_active (priority 5).
	game.quest = .Not_Started
	idx, ok := dialogue_select_conv(&content, game, .Old_Miner)
	testing.expect(t, ok)
	testing.expect(t, idx >= 0)
	convs := content.registry.dialogue.conversations
	testing.expect_value(t, convs[idx].id, "old_miner_intro")
}

@(test)
dialogue_select_conv_returns_false_when_no_conversation_matches :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)

	// Quest Not_Started + old_miner_intro already seen → no match (one_shot seen).
	game.quest = .Not_Started
	dialogue_mark_seen(game, "old_miner_intro")
	// old_miner_active requires quest Active, old_miner_found requires Treasure_Found
	// → no Old_Miner conversation matches
	_, ok := dialogue_select_conv(&content, game, .Old_Miner)
	testing.expect(t, !ok)
}

@(test)
dialogue_select_conv_respects_quest_state_filter :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)

	// Quest Active: old_miner_active should be selected (intro is one_shot and requires Not_Started).
	game.quest = .Active
	idx, ok := dialogue_select_conv(&content, game, .Old_Miner)
	testing.expect(t, ok)
	convs := content.registry.dialogue.conversations
	testing.expect_value(t, convs[idx].id, "old_miner_active")
}


// ─── dialogue flags ──────────────────────────────────────────────────────────

@(test)
dialogue_has_flag_returns_false_when_flag_not_set :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)

	testing.expect(t, !dialogue_has_flag(game, "test_flag"))
}

@(test)
dialogue_set_flag_makes_has_flag_return_true :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)

	dialogue_set_flag(game, "my_flag")
	testing.expect(t, dialogue_has_flag(game, "my_flag"))
}

@(test)
dialogue_set_flag_is_idempotent :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)

	dialogue_set_flag(game, "dup_flag")
	dialogue_set_flag(game, "dup_flag")
	testing.expect_value(t, game.dlg_flag_count, 1)
}

@(test)
dialogue_clear_flag_removes_the_flag :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)

	dialogue_set_flag(game, "to_remove")
	dialogue_set_flag(game, "keeper")
	dialogue_clear_flag(game, "to_remove")

	testing.expect(t, !dialogue_has_flag(game, "to_remove"))
	testing.expect(t, dialogue_has_flag(game, "keeper"))
	testing.expect_value(t, game.dlg_flag_count, 1)
}


// ─── seen conversations ──────────────────────────────────────────────────────

@(test)
dialogue_has_seen_returns_false_for_unseen_conversation :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)

	testing.expect(t, !dialogue_has_seen(game, "old_miner_intro"))
}

@(test)
dialogue_mark_seen_makes_has_seen_return_true :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)

	dialogue_mark_seen(game, "old_miner_intro")
	testing.expect(t, dialogue_has_seen(game, "old_miner_intro"))
}

@(test)
dialogue_mark_seen_is_idempotent :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)

	dialogue_mark_seen(game, "conv_a")
	dialogue_mark_seen(game, "conv_a")
	testing.expect_value(t, game.seen_count, 1)
}


// ─── start_conversation / advance_dialogue ───────────────────────────────────

@(test)
start_conversation_sets_state_to_viewing_dialogue :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)
	game.depth = SURFACE_DEPTH
	generate_map(&content, game)

	messages := message_manager_make()

	miner_idx := -1
	for i in 0 ..< game.npc_count {
		if game.npcs[i].role == .Old_Miner {miner_idx = i}
	}
	testing.expect(t, miner_idx >= 0)

	game.quest = .Not_Started
	start_conversation(&messages, &content, game, miner_idx)
	testing.expect(t, game.state == .Viewing_Dialogue)
	testing.expect(t, game.active_conv_idx >= 0)
	testing.expect(t, game.active_node_idx >= 0)
}

@(test)
start_conversation_does_nothing_when_no_conversation_matches :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)
	game.depth = SURFACE_DEPTH
	generate_map(&content, game)

	messages := message_manager_make()

	miner_idx := -1
	for i in 0 ..< game.npc_count {
		if game.npcs[i].role == .Old_Miner {miner_idx = i}
	}
	testing.expect(t, miner_idx >= 0)

	// Set quest to Complete and mark found as seen — no Old_Miner conversation matches.
	game.state = .Playing
	game.quest = .Complete
	dialogue_mark_seen(game, "old_miner_found")
	start_conversation(&messages, &content, game, miner_idx)
	// State must remain Playing — no conversation was found.
	testing.expect_value(t, game.state, Game_State.Playing)
}

@(test)
close_dialogue_resets_active_state :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)
	game.depth = SURFACE_DEPTH
	generate_map(&content, game)

	messages := message_manager_make()

	miner_idx := -1
	for i in 0 ..< game.npc_count {
		if game.npcs[i].role == .Old_Miner {miner_idx = i}
	}
	testing.expect(t, miner_idx >= 0)

	game.quest = .Not_Started
	start_conversation(&messages, &content, game, miner_idx)
	testing.expect(t, game.state == .Viewing_Dialogue)

	close_dialogue(game)
	testing.expect_value(t, game.state, Game_State.Playing)
	testing.expect_value(t, game.active_conv_idx, -1)
	testing.expect_value(t, game.active_node_idx, -1)
}

@(test)
one_shot_conversation_is_marked_seen_after_completion :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)
	game.depth = SURFACE_DEPTH
	generate_map(&content, game)

	messages := message_manager_make()

	miner_idx := -1
	for i in 0 ..< game.npc_count {
		if game.npcs[i].role == .Old_Miner {miner_idx = i}
	}
	testing.expect(t, miner_idx >= 0)

	game.quest = .Not_Started
	testing.expect(t, !dialogue_has_seen(game, "old_miner_intro"))

	start_conversation(&messages, &content, game, miner_idx)
	// hook → offer
	advance_dialogue(&messages, &content, game)
	// Choose "Not interested." (choice 1) → decline, no effects
	game.dialogue_choice = 1
	confirm_dialogue_choice(&messages, &content, game)
	// decline has no next → conversation closes
	advance_dialogue(&messages, &content, game)

	testing.expect(t, dialogue_has_seen(game, "old_miner_intro"))
}


// ─── save/restore dialogue state ─────────────────────────────────────────────

@(test)
save_restore_preserves_dialogue_flags_and_seen_conversations :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)
	game.depth = SURFACE_DEPTH
	game.quest = Quest_State.Active
	generate_map(&content, game)

	dialogue_set_flag(game, "flag_a")
	dialogue_set_flag(game, "flag_b")
	dialogue_mark_seen(game, "old_miner_intro")

	path := "/tmp/into-the-dark-dialogue-test.dat"
	turns := eng.turn_manager_make()
	testing.expect(t, save_game_to_path(&turns, game, path))

	loaded := game_init(&content)
	defer game_destroy(loaded)
	loaded_turns := eng.turn_manager_make()
	camera := eng.camera_manager_make()
	vfx := eng.vfx_manager_make()
	ui := ui_manager_make(false)
	loaded_messages := message_manager_make()

	testing.expect(
		t,
		load_game_from_path(
			&content,
			&loaded_turns,
			&camera,
			&vfx,
			&ui,
			&loaded_messages,
			loaded,
			path,
		),
	)

	testing.expect(t, dialogue_has_flag(loaded, "flag_a"))
	testing.expect(t, dialogue_has_flag(loaded, "flag_b"))
	testing.expect(t, !dialogue_has_flag(loaded, "flag_c"))
	testing.expect(t, dialogue_has_seen(loaded, "old_miner_intro"))
	testing.expect(t, !dialogue_has_seen(loaded, "old_miner_active"))
}
