#+build !js
package main


when CHEATS_ENABLED {

	@(test)
	cheat_menu_toggle_opens_cheat_overlay_in_cheat_build :: proc(t: ^testing.T) {
		game: Game
		game.state = .Playing
		ui := ui_manager_make(false)
		input_state := Test_Input_Backend_State{}
		input_state.pressed[eng.Engine_Key.C] = true
		input_state.down[eng.Engine_Key.Left_Shift] = true
		input := input_manager_make()
		input.backend = test_input_backend(&input_state)

		opened := cheat_open_if_requested(&ui, &game, &input)

		testing.expect(t, opened)
		testing.expect_value(t, game.state, Game_State.Viewing_Cheats)
		testing.expect_value(t, ui.state.cheat_choice, 0)
	}

	@(test)
	cheat_heal_restores_player_to_full_health :: proc(t: ^testing.T) {
		game: Game
		game.player.hp = 3
		game.player.max_hp = 25
		messages := message_manager_make()
		content := content_manager_make()
		turns := eng.turn_manager_make()
		camera := eng.camera_manager_make()

		cheat_apply(&content, &turns, &camera, &messages, &game, .Heal_Full)

		testing.expect_value(t, game.player.hp, 25)
		testing.expect_value(t, messages.log.count, 1)
	}

	@(test)
	cheat_teleport_to_descent_moves_player_to_existing_descent_tile :: proc(t: ^testing.T) {
		game: Game
		game.player.pos = Vec2{1, 1}
		game.tiles[pos_to_idx(7, 9)].type = .Descent
		messages := message_manager_make()
		content := content_manager_make()
		turns := eng.turn_manager_make()
		camera := eng.camera_manager_make()

		cheat_apply(&content, &turns, &camera, &messages, &game, .Teleport_Descent)

		testing.expect_value(t, game.player.pos, Vec2{7, 9})
	}

	@(test)
	cheat_depth_jump_clamps_and_regenerates_target_depth :: proc(t: ^testing.T) {
		game: Game
		game.depth = 1
		game.state = .Playing
		game.rooms = make([dynamic]Room)
		game.enemies = make([dynamic]Enemy)
		game.items = make([dynamic]Item)
		game.light_sources = make([dynamic]Light_Source)
		defer game_cleanup(&game)
		content := content_manager_make()
		content.registry.player.light_radius = 6
		messages := message_manager_make()
		turns := eng.turn_manager_make()
		camera := eng.camera_manager_make()

		cheat_set_depth(&content, &turns, &camera, &messages, &game, 99)

		testing.expect_value(t, game.depth, MAX_DEPTH)
		_, descent_ok := cheat_find_descent(&game)
		testing.expect(t, descent_ok)
		testing.expect(t, game.player.pos.x > 0 || game.player.pos.y > 0)
	}

	@(test)
	cheat_menu_number_shortcuts_apply_commands :: proc(t: ^testing.T) {
		game: Game
		game.state = .Viewing_Cheats
		game.player.hp = 1
		game.player.max_hp = 10
		ui := ui_manager_make(false)
		messages := message_manager_make()
		content := content_manager_make()
		turns := eng.turn_manager_make()
		camera := eng.camera_manager_make()
		input_state := Test_Input_Backend_State{}
		input_state.pressed[eng.Engine_Key.One] = true
		input := input_manager_make()
		input.backend = test_input_backend(&input_state)

		update_viewing_cheats(&content, &turns, &camera, &messages, &ui, &game, &input)

		testing.expect_value(t, game.player.hp, 10)
		testing.expect_value(t, game.state, Game_State.Playing)
	}
}
