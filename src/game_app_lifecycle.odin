package main

import eng "./engine"

game_app_enforce_build_flags :: proc(engine: ^eng.Engine) {
	when NO_SPRITES {
		ui := ui_manager_state(game_engine_ui_manager(engine))
		if ui != nil {
			ui.use_sprites = false
		}
	}
}

game_app_make :: proc() -> eng.Game_App {
	return eng.Game_App {
		name = "Into the Depths",
		init = game_app_init,
		update = game_app_update,
		render = game_app_render,
		shutdown = game_app_shutdown,
		autosave = game_app_autosave,
	}
}

game_app_state :: proc(app: ^eng.Game_App) -> ^Into_The_Depths_App_State {
	if app == nil || app.state == nil {
		return nil
	}
	return cast(^Into_The_Depths_App_State)app.state
}

game_app_init :: proc(engine: ^eng.Engine, app: ^eng.Game_App) -> bool {
	state := new(Into_The_Depths_App_State)
	app.state = state

	when !NO_SPRITES {
		sprites_init(engine)
	}

	if !game_engine_register_app_services(engine) {
		logger_fatalf(.App, "Failed to register app services. Exiting.")
		when !NO_SPRITES {
			sprites_cleanup(engine)
		}
		free(state)
		app.state = nil
		return false
	}

	content := game_engine_content_manager(engine)
	if content == nil || !content_manager_load_all(content) {
		logger_fatalf(.App, "Failed to load data files. Exiting.")
		when !NO_SPRITES {
			sprites_cleanup(engine)
		}
		free(state)
		app.state = nil
		return false
	}

	message_manager_bind_turns(
		game_engine_message_manager(engine),
		game_engine_turn_manager(engine),
	)

	state.game = game_init(content)
	if !game_scene_manager_init(state.scene_descriptors[:], engine, state.game) {
		logger_fatalf(.App, "Failed to initialize scene manager. Exiting.")
		game_destroy(state.game)
		when !NO_SPRITES {
			sprites_cleanup(engine)
		}
		free(state)
		app.state = nil
		return false
	}

	game := state.game
	logger_debugf(.Init, "seed = %v", game.seed)

	compute_fov(game)
	game_camera_update(game_engine_camera_manager(engine), game, true)
	game_app_enforce_build_flags(engine)
	if !clay_ui_init(engine) {
		logger_fatalf(.App, "Failed to initialize Clay UI. Exiting.")
		game_destroy(state.game)
		when !NO_SPRITES {
			sprites_cleanup(engine)
		}
		free(state)
		app.state = nil
		return false
	}
	add_message(
		game_engine_message_manager(engine),
		game,
		"Welcome to the depths. Tread carefully...",
		eng.Engine_Color{200, 200, 100, 255},
	)

	register_restart_game(restart_game)
	register_handle_player_action(handle_player_action)
	return true
}

game_app_update :: proc(engine: ^eng.Engine, app: ^eng.Game_App) -> bool {
	state := game_app_state(app)
	if state == nil || state.game == nil {
		return true
	}

	game := state.game
	when !NO_AUDIO {
		music_update(game)
	}
	game_app_enforce_build_flags(engine)
	handle_global_input(engine, game, game_engine_input_manager(engine))
	return game_scene_manager_update(engine, game)
}

game_app_render :: proc(engine: ^eng.Engine, app: ^eng.Game_App) {
	state := game_app_state(app)
	if state == nil || state.game == nil {
		return
	}
	game_scene_manager_render(engine, state.game)
}

game_app_autosave :: proc(engine: ^eng.Engine, app: ^eng.Game_App) {
	state := game_app_state(app)
	if state == nil || state.game == nil {
		return
	}

	saves := game_engine_save_manager(engine)
	if state.game.state == .Playing && saves != nil {
		save_manager_save_game(saves, game_engine_turn_manager(engine), state.game)
	}
}

game_app_shutdown :: proc(engine: ^eng.Engine, app: ^eng.Game_App) {
	state := game_app_state(app)
	if state == nil {
		return
	}
	if state.game != nil {
		game_destroy(state.game)
	}
	clay_ui_destroy()
	when !NO_SPRITES {
		sprites_cleanup(engine)
	}
	free(state)
	app.state = nil
}
