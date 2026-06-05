#+build !js
package main

import eng "./engine"
import "core:testing"

@(test)
frozen_status_doubles_player_movement_energy_cost :: proc(t: ^testing.T) {
	game: Game
	game.player.pos = Vec2{1, 1}
	game.player.energy = 5000
	game.frozen_turns = 2
	game.tiles[pos_to_idx(1, 1)].type = .Floor
	game.tiles[pos_to_idx(2, 1)].type = .Floor

	backend_state := Test_Input_Backend_State{}
	backend_state.down[eng.Engine_Key.D] = true
	input := input_manager_make()
	input.backend = test_input_backend(&backend_state)
	content := content_manager_make()
	turns := eng.turn_manager_make()
	camera := eng.camera_manager_make()
	messages := message_manager_make()

	result := handle_input(&content, &turns, &camera, &messages, &game, &input)

	testing.expect_value(t, result, Input_Result.Moved)
	testing.expect_value(t, game.player.pos, Vec2{2, 1})
	testing.expect_value(t, game.player.energy, 5000 - BASE_MOVE_COST * 2)
}

@(test)
frozen_status_ticks_down_and_announces_thaw :: proc(t: ^testing.T) {
	game: Game
	game.frozen_turns = 1
	messages := message_manager_make()

	tick_timed_effects(&messages, &game)

	testing.expect_value(t, game.frozen_turns, 0)
	testing.expect_value(t, messages.log.count, 1)
	testing.expect(
		t,
		string(messages.log.messages[0].text[:messages.log.messages[0].text_len]) ==
		"The ice thaws. You can move freely.",
	)
}

@(test)
timed_effects_do_not_tick_after_game_over :: proc(t: ^testing.T) {
	game: Game
	game.state = .Game_Over
	game.player.hp = 1
	game.poison_turns = 2
	game.burning_turns = 2
	game.frozen_turns = 2
	game.death_cause = "Already dead"
	messages := message_manager_make()

	tick_timed_effects(&messages, &game)

	testing.expect_value(t, game.player.hp, 1)
	testing.expect_value(t, game.poison_turns, 2)
	testing.expect_value(t, game.burning_turns, 2)
	testing.expect_value(t, game.frozen_turns, 2)
	testing.expect(t, game.death_cause == "Already dead")
	testing.expect_value(t, messages.log.count, 0)
}

@(test)
timed_effects_stop_when_poison_kills_player :: proc(t: ^testing.T) {
	game: Game
	game.state = .Playing
	game.player.hp = 1
	game.poison_turns = 1
	game.burning_turns = 1
	messages := message_manager_make()

	tick_timed_effects(&messages, &game)

	testing.expect_value(t, game.state, Game_State.Game_Over)
	testing.expect_value(t, game.player.hp, 0)
	testing.expect_value(t, game.poison_turns, 0)
	testing.expect_value(t, game.burning_turns, 1)
	testing.expect(t, game.death_cause == "Died from poison")
}

@(test)
footstep_sound_selection_matches_tile_material :: proc(t: ^testing.T) {
	testing.expect_value(t, footstep_sound_for_tile(.Water), Sound_Type.Water)
	testing.expect_value(t, footstep_sound_for_tile(.Rubble), Sound_Type.Step_Rubble)
	testing.expect_value(t, footstep_sound_for_tile(.Anvil), Sound_Type.Step_Stone)
	testing.expect_value(t, footstep_sound_for_tile(.Floor), Sound_Type.Footstep)
}

@(test)
locked_door_requires_and_consumes_vault_key :: proc(t: ^testing.T) {
	game: Game
	game.player.pos = Vec2{1, 1}
	game.player.energy = 5000
	game.tiles[pos_to_idx(1, 1)].type = .Floor
	game.tiles[pos_to_idx(2, 1)].type = .Locked_Door
	game.inventory[0] = Inventory_Slot {
		occupied = true,
		item = Item{item_type = "vault_key", name = "Vault Key", quantity = 1},
	}

	backend_state := Test_Input_Backend_State{}
	backend_state.down[eng.Engine_Key.D] = true
	input := input_manager_make()
	input.backend = test_input_backend(&backend_state)
	content := content_manager_make()
	turns := eng.turn_manager_make()
	camera := eng.camera_manager_make()
	messages := message_manager_make()

	result := handle_input(&content, &turns, &camera, &messages, &game, &input)

	testing.expect_value(t, result, Input_Result.Acted)
	testing.expect(t, !game.inventory[0].occupied)
	testing.expect_value(t, game.tiles[pos_to_idx(2, 1)].type, Tile_Type.Floor)
	testing.expect_value(t, game.player.energy, 5000 - BASE_ACTION_COST)
}

@(test)
adjacent_attack_consumes_action_without_consuming_web_under_player :: proc(t: ^testing.T) {
	services := eng.engine_services_make(eng.engine_services_default_config())
	defer eng.engine_services_destroy(&services)
	backend_state := Test_Input_Backend_State{}
	backend_state.down[eng.Engine_Key.D] = true
	engine := action_result_test_engine(&services, &backend_state)
	testing.expect(t, game_engine_register_app_services(&engine))

	game := action_result_test_game()
	defer delete(game.enemies)
	append(
		&game.enemies,
		Enemy {
			pos = Vec2{2, 1},
			hp = 1,
			max_hp = 1,
			alive = true,
			quickness = 100,
			move_speed = 100,
		},
	)
	testing.expect(t, web_tile_set(&game, 1, 1, true))

	quit := handle_player_action(&engine, &game)

	testing.expect(t, !quit)
	testing.expect_value(t, game.player.pos, Vec2{1, 1})
	testing.expect_value(t, game.player.energy, BASE_AP_PER_ROUND)
	testing.expect_value(t, eng.turn_manager_current(&engine.turn_manager), 1)
	testing.expect(t, web_tile_at(&game, 1, 1))
	testing.expect(t, !game.skip_next_turn)
}

@(test)
locked_door_unlock_consumes_action_without_consuming_web_under_player :: proc(t: ^testing.T) {
	services := eng.engine_services_make(eng.engine_services_default_config())
	defer eng.engine_services_destroy(&services)
	backend_state := Test_Input_Backend_State{}
	backend_state.down[eng.Engine_Key.D] = true
	engine := action_result_test_engine(&services, &backend_state)
	testing.expect(t, game_engine_register_app_services(&engine))

	game := action_result_test_game()
	defer delete(game.enemies)
	game.tiles[pos_to_idx(2, 1)].type = .Locked_Door
	game.inventory[0] = Inventory_Slot {
		occupied = true,
		item = Item{item_type = "vault_key", name = "Vault Key", quantity = 1},
	}
	testing.expect(t, web_tile_set(&game, 1, 1, true))

	quit := handle_player_action(&engine, &game)

	testing.expect(t, !quit)
	testing.expect_value(t, game.player.pos, Vec2{1, 1})
	testing.expect_value(t, game.player.energy, BASE_AP_PER_ROUND)
	testing.expect_value(t, eng.turn_manager_current(&engine.turn_manager), 1)
	testing.expect_value(t, game.tiles[pos_to_idx(2, 1)].type, Tile_Type.Floor)
	testing.expect(t, !game.inventory[0].occupied)
	testing.expect(t, web_tile_at(&game, 1, 1))
	testing.expect(t, !game.skip_next_turn)
}

@(test)
treasure_vault_seals_room_perimeter_except_locked_door :: proc(t: ^testing.T) {
	game: Game
	room := Room{10, 10, 15, 15}
	carve_rect(&game, room.x1, room.y1, room.x2, room.y2)
	game.tiles[pos_to_idx(12, 9)].type = .Floor
	door := Vec2{12, 10}

	seal_room_perimeter_for_vault(&game, room, door)

	for y in room.y1 ..< room.y2 {
		for x in room.x1 ..< room.x2 {
			on_perimeter := x == room.x1 || x == room.x2 - 1 || y == room.y1 || y == room.y2 - 1
			if !on_perimeter {continue}
			if x == door.x && y == door.y {
				testing.expect_value(t, game.tiles[pos_to_idx(x, y)].type, Tile_Type.Locked_Door)
			} else {
				testing.expect_value(t, game.tiles[pos_to_idx(x, y)].type, Tile_Type.Wall)
			}
		}
	}
	testing.expect_value(t, game.tiles[pos_to_idx(12, 11)].type, Tile_Type.Floor)
	testing.expect_value(t, game.tiles[pos_to_idx(12, 9)].type, Tile_Type.Floor)
}

@(test)
victory_boss_status_text_reports_whether_boss_was_defeated :: proc(t: ^testing.T) {
	game: Game
	testing.expect(t, string(victory_boss_status_text(&game)) == "Not defeated")
	game.boss_killed_this_turn = true
	testing.expect(t, string(victory_boss_status_text(&game)) == "Defeated")
}

action_result_test_engine :: proc(
	services: ^eng.Engine_Services,
	backend_state: ^Test_Input_Backend_State,
) -> eng.Engine {
	input_backend := test_input_backend(backend_state)
	return eng.Engine {
		services = services,
		input = input_backend,
		audio = eng.engine_audio_backend_nil(),
		audio_manager = eng.audio_manager_make(eng.engine_audio_backend_nil()),
		camera_manager = eng.camera_manager_make(),
		turn_manager = eng.turn_manager_make(),
		vfx_manager = eng.vfx_manager_make(),
		message_manager = eng.message_manager_make(),
		particle_manager = eng.particle_manager_make(),
	}
}

action_result_test_game :: proc() -> Game {
	game: Game
	game_init_world(&game)
	for &tile in game.tiles {
		tile.type = .Wall
	}
	game.tiles[pos_to_idx(1, 1)].type = .Floor
	game.tiles[pos_to_idx(2, 1)].type = .Floor
	game.player.pos = Vec2{1, 1}
	game.player.hp = 20
	game.player.max_hp = 20
	game.player.attack = 5
	game.player.energy = BASE_ACTION_COST
	game.player.quickness = 100
	game.player.move_speed = 100
	game.state = .Playing
	game.enemies = make([dynamic]Enemy)
	return game
}
