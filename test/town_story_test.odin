#+build !js
package main

import "core:testing"

@(test)
game_starts_on_surface_with_npcs_and_mine_entrance :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)
	game.state = .Playing
	game.depth = SURFACE_DEPTH
	generate_map(&content, game)

	// Town has NPCs including a quest-giver.
	testing.expect(t, game.npc_count > 0)
	has_quest_giver := false
	for i in 0 ..< game.npc_count {
		if game.npcs[i].role == .Old_Miner {has_quest_giver = true}
	}
	testing.expect(t, has_quest_giver)

	// Mine entrance (Descent tile) exists on the surface.
	has_entrance := false
	for tile in game.tiles {
		if tile.type == .Descent {has_entrance = true}
	}
	testing.expect(t, has_entrance)

	// No enemies on the surface.
	testing.expect_value(t, len(game.enemies), 0)
}

@(test)
talking_to_old_miner_activates_quest :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)
	game.depth = SURFACE_DEPTH
	generate_map(&content, game)
	messages := message_manager_make()

	// Find the Old Miner and start dialogue.
	miner_idx := -1
	for i in 0 ..< game.npc_count {
		if game.npcs[i].role == .Old_Miner {miner_idx = i}
	}
	testing.expect(t, miner_idx >= 0)

	game.active_npc = miner_idx
	game.dialogue_line = 0
	game.quest = .Not_Started

	// Advance through every line — quest activates on the final line.
	lines := npc_dialogue(game, &game.npcs[miner_idx])
	for _ in 0 ..< len(lines) {
		advance_dialogue(&messages, game)
	}

	testing.expect_value(t, game.quest, Quest_State.Active)
	testing.expect_value(t, game.active_npc, -1) // dialogue closed
}

@(test)
ancient_treasure_spawns_at_max_depth :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)
	game.state = .Playing
	game.depth = MAX_DEPTH
	generate_map(&content, game)

	has_treasure := false
	for &it in game.items {
		if it.item_type == ITEM_ID_ANCIENT_TREASURE {has_treasure = true}
	}
	testing.expect(t, has_treasure)

	// No descent on the final floor — the treasure is the goal.
	has_descent := false
	for tile in game.tiles {
		if tile.type == .Descent {has_descent = true}
	}
	testing.expect(t, !has_descent)
}

@(test)
picking_up_treasure_advances_quest :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)
	game.state = .Playing
	game.depth = MAX_DEPTH
	game.quest = .Active
	generate_map(&content, game)
	messages := message_manager_make()

	// Move the player onto the treasure and pick it up.
	for &it in game.items {
		if it.item_type == ITEM_ID_ANCIENT_TREASURE {
			game.player.pos = it.pos
		}
	}
	testing.expect(t, pickup_item(&content, &messages, game))
	testing.expect_value(t, game.quest, Quest_State.Treasure_Found)
}
