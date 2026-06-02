package main

import rl "vendor:raylib"

// ─── Into the Depths app adapter ─────────────────────────────────────────────

Into_The_Depths_App_State :: struct {
	game: ^Game,
}

game_app_make :: proc() -> Game_App {
	return Game_App {
		name     = "Into the Depths",
		init     = game_app_init,
		update   = game_app_update,
		render   = game_app_render,
		shutdown = game_app_shutdown,
		autosave = game_app_autosave,
	}
}

game_app_state :: proc(app: ^Game_App) -> ^Into_The_Depths_App_State {
	if app == nil || app.state == nil {
		return nil
	}
	return cast(^Into_The_Depths_App_State)app.state
}

game_app_init :: proc(engine: ^Engine, app: ^Game_App) -> bool {
	if !data_load_all() {
		logger_fatalf(.App, "Failed to load data files. Exiting.")
		return false
	}

	state := new(Into_The_Depths_App_State)
	state.game = game_init()
	app.state = state

	game := state.game
	logger_debugf(.Init, "seed = %v", game.seed)

	compute_fov(game)
	camera_update(game, snap = true)
	add_message(game, "Welcome to the depths. Tread carefully...", rl.Color{200, 200, 100, 255})

	return true
}

game_app_update :: proc(engine: ^Engine, app: ^Game_App) -> bool {
	state := game_app_state(app)
	if state == nil || state.game == nil {
		return true
	}

	game := state.game
	handle_global_input(game, &game.input)

	switch game.state {
	case .Title_Screen:
		return update_title_screen(game, &game.input)
	case .Playing:
		return update_playing(game, &game.input)
	case .Game_Over:
		return update_game_over(game, &game.input)
	case .Victory:
		return update_victory(game, &game.input)
	case .Viewing_Inventory:
		update_viewing_inventory(game, &game.input)
	case .Viewing_Crafting:
		update_viewing_crafting(game, &game.input)
	case .Viewing_Help:
		update_viewing_help(game, &game.input)
	case .Viewing_Scores:
		update_viewing_scores(game, &game.input)
	}

	return false
}

game_app_render :: proc(engine: ^Engine, app: ^Game_App) {
	state := game_app_state(app)
	if state == nil || state.game == nil {
		return
	}
	render_game(state.game)
}

game_app_autosave :: proc(engine: ^Engine, app: ^Game_App) {
	state := game_app_state(app)
	if state == nil || state.game == nil {
		return
	}

	if state.game.state == .Playing {
		save_game(state.game)
	}
}

game_app_shutdown :: proc(engine: ^Engine, app: ^Game_App) {
	state := game_app_state(app)
	if state == nil {
		return
	}
	if state.game != nil {
		game_destroy(state.game)
	}
	free(state)
	app.state = nil
}
