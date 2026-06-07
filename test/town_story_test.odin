#+build !js
package main

import eng "./engine"
import "core:os"
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

@(test)
talking_to_shopkeeper_opens_fixed_town_shop :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)
	game.depth = SURFACE_DEPTH
	generate_map(&content, game)
	messages := message_manager_make()

	shopkeeper_idx := -1
	for i in 0 ..< game.npc_count {
		if game.npcs[i].role == .Shopkeeper {shopkeeper_idx = i}
	}
	testing.expect(t, shopkeeper_idx >= 0)

	game.active_npc = shopkeeper_idx
	game.dialogue_line = 0
	lines := npc_dialogue(game, &game.npcs[shopkeeper_idx])
	for _ in 0 ..< len(lines) {
		advance_dialogue(&messages, game)
	}

	testing.expect_value(t, game.state, Game_State.Viewing_Merchant)
	testing.expect_value(t, game.active_npc, -1)
	testing.expect_value(t, game.merchant_stock[0].item_id, ITEM_ID_BANDAGE)
	testing.expect_value(t, game.merchant_stock[0].cost_id, "iron_ore")
	testing.expect_value(t, game.merchant_stock[0].cost_qty, 1)
	testing.expect_value(t, game.merchant_stock[1].item_id, ITEM_ID_TORCH)
	testing.expect_value(t, game.merchant_stock[1].cost_id, "copper_ore")
	testing.expect_value(t, game.merchant_stock[1].cost_qty, 1)
	testing.expect_value(t, game.merchant_stock[2].item_id, "health_potion")
	testing.expect_value(t, game.merchant_stock[2].cost_id, "iron_ore")
	testing.expect_value(t, game.merchant_stock[2].cost_qty, 2)
}

@(test)
shopkeeper_trade_and_leave_preserves_surface_shop :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)
	game.depth = SURFACE_DEPTH
	generate_map(&content, game)
	generate_shopkeeper_stock(game)
	game.state = .Viewing_Merchant
	game.player.pos = Vec2{5, 5}
	game.tiles[pos_to_idx(5, 5)].type = .Merchant
	game.event_used = false

	merchant_leave_shop(nil, game)

	testing.expect_value(t, game.state, Game_State.Playing)
	testing.expect_value(t, game.tiles[pos_to_idx(5, 5)].type, Tile_Type.Merchant)
	testing.expect(t, !game.event_used)
	testing.expect(t, game.npc_count > 0)
}

@(test)
buying_from_shopkeeper_consumes_material_and_marks_offer_sold :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)
	game.inventory = {}
	generate_shopkeeper_stock(game)

	iron_def := content_manager_item_def(&content, "iron_ore")
	testing.expect(t, iron_def != nil)
	iron := item_make_from_def(iron_def, game.player.pos)
	iron.picked_up = true
	testing.expect(t, inventory_put_slot(game, 0, iron, 1))

	services := engine_services_make(engine_services_default_config())
	defer engine_services_destroy(&services)
	engine: Engine
	engine.services = &services
	engine.message_manager = message_manager_make()
	testing.expect(t, engine_services_register(&services, GAME_ENGINE_SERVICE_CONTENT, &content))
	testing.expect(
		t,
		engine_services_register(&services, GAME_ENGINE_SERVICE_MESSAGES, &engine.message_manager),
	)

	testing.expect(t, merchant_buy(&engine, game, 0))

	testing.expect(t, game.merchant_stock[0].sold)
	testing.expect_value(t, inventory_count_item_type(game, "iron_ore"), 0)
	testing.expect_value(t, inventory_count_item_type(game, ITEM_ID_BANDAGE), 1)
}

@(test)
descending_then_ascending_restores_previous_floor_entities_and_items :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)
	game.depth = 1
	generate_map(&content, game)
	previous_pos := Vec2{10, 10}
	game.player.pos = previous_pos
	game.tiles[pos_to_idx(previous_pos.x, previous_pos.y)].type = .Descent
	append(&game.enemies, Enemy{pos = Vec2{3, 3}, enemy_type = "rat", alive = true})
	append(&game.items, Item{pos = Vec2{4, 4}, item_type = ITEM_ID_BANDAGE, name = "Bandage"})
	previous_enemy_count := len(game.enemies)
	previous_item_count := len(game.items)
	messages := message_manager_make()
	camera := eng.camera_manager_make()

	descend(&content, &camera, &messages, game)
	entry := game.player.pos
	testing.expect_value(t, game.depth, 2)
	testing.expect_value(t, tile_at(game, entry.x, entry.y).type, Tile_Type.Ascent)

	testing.expect(t, ascend(&content, &camera, &messages, game))

	testing.expect_value(t, game.depth, 1)
	testing.expect_value(t, game.player.pos, previous_pos)
	testing.expect_value(t, len(game.enemies), previous_enemy_count)
	testing.expect_value(t, len(game.items), previous_item_count)
	testing.expect(t, enemy_at(game, 3, 3) != nil)
	testing.expect(t, item_at(game, 4, 4) != nil)
}

@(test)
ascending_from_first_mine_floor_restores_surface_town :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)
	game.depth = SURFACE_DEPTH
	generate_map(&content, game)
	messages := message_manager_make()
	camera := eng.camera_manager_make()

	descend(&content, &camera, &messages, game)
	testing.expect_value(t, game.depth, 1)

	testing.expect(t, ascend(&content, &camera, &messages, game))

	testing.expect_value(t, game.depth, SURFACE_DEPTH)
	testing.expect(t, game.npc_count > 0)
	testing.expect(t, npc_at(game, game.player.pos.x, game.player.pos.y) < 0)
}

@(test)
save_load_preserves_floor_stack_for_return_trip :: proc(t: ^testing.T) {
	path := "/tmp/into-the-depths-floor-stack-save.dat"
	defer os.remove(path)

	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)
	game.depth = SURFACE_DEPTH
	generate_map(&content, game)
	game.tiles[pos_to_idx(5, 5)].type = .Chest
	messages := message_manager_make()
	camera := eng.camera_manager_make()
	descend(&content, &camera, &messages, game)

	turns := eng.turn_manager_make()
	testing.expect(t, save_game_to_path(&turns, game, path))

	loaded: Game
	loaded_turns := eng.turn_manager_make()
	loaded_camera := eng.camera_manager_make()
	vfx := eng.vfx_manager_make()
	ui := ui_manager_make(false)
	loaded_messages := message_manager_make()
	testing.expect(
		t,
		load_game_from_path(
			&content,
			&loaded_turns,
			&loaded_camera,
			&vfx,
			&ui,
			&loaded_messages,
			&loaded,
			path,
		),
	)
	defer game_cleanup(&loaded)

	testing.expect(t, ascend(&content, &loaded_camera, &loaded_messages, &loaded))

	testing.expect_value(t, loaded.depth, SURFACE_DEPTH)
	testing.expect_value(t, loaded.tiles[pos_to_idx(5, 5)].type, Tile_Type.Chest)
}

@(test)
treasure_can_be_carried_back_to_old_miner_by_ascending :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)
	game.depth = SURFACE_DEPTH
	game.quest = Quest_State.Active
	generate_map(&content, game)
	messages := message_manager_make()
	camera := eng.camera_manager_make()

	for _ in SURFACE_DEPTH ..< MAX_DEPTH {
		descend(&content, &camera, &messages, game)
	}
	testing.expect_value(t, game.depth, MAX_DEPTH)

	for &it in game.items {
		if it.item_type == ITEM_ID_ANCIENT_TREASURE {
			game.player.pos = it.pos
			break
		}
	}
	testing.expect(t, pickup_item(&content, &messages, game))
	testing.expect_value(t, game.quest, Quest_State.Treasure_Found)

	for _ in SURFACE_DEPTH ..< MAX_DEPTH {
		testing.expect(t, ascend(&content, &camera, &messages, game))
	}
	testing.expect_value(t, game.depth, SURFACE_DEPTH)

	miner_idx := -1
	for i in 0 ..< game.npc_count {
		if game.npcs[i].role == .Old_Miner {miner_idx = i}
	}
	testing.expect(t, miner_idx >= 0)
	game.active_npc = miner_idx
	lines := npc_dialogue(game, &game.npcs[miner_idx])
	for _ in 0 ..< len(lines) {
		advance_dialogue(&messages, game)
	}

	testing.expect_value(t, game.quest, Quest_State.Complete)
	testing.expect_value(t, game.state, Game_State.Victory)
}
