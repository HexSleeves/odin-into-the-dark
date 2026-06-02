package main

import rl "vendor:raylib"
import eng "./engine"

// ─── Into the Depths app adapter ─────────────────────────────────────────────

Into_The_Depths_App_State :: struct {
	game:              ^Game,
	content:           Content_Manager,
	saves:             Save_Manager,
	scene_manager:     eng.Scene_Manager,
	scene_descriptors: [GAME_SCENE_COUNT]eng.Engine_Scene,
}

game_engine_config :: proc() -> eng.Engine_Config {
	return eng.engine_config_make(SCREEN_WIDTH, SCREEN_HEIGHT, "Into the Depths", 60)
}

game_engine_services_config :: proc() -> eng.Engine_Services_Config {
	return eng.Engine_Services_Config {
		diagnostics_init = game_diagnostics_init,
		diagnostics_shutdown = game_diagnostics_shutdown,
		runtime_assets_init = game_runtime_assets_init,
		runtime_assets_shutdown = game_runtime_assets_shutdown,
	}
}

game_diagnostics_init :: proc() {
	logger_init_from_env(&g_logger)
}

game_diagnostics_shutdown :: proc() {
	logger_destroy(&g_logger)
}

game_runtime_assets_init :: proc() {
	audio_init()
	sprites_init()
}

game_runtime_assets_shutdown :: proc() {
	sprites_cleanup()
	audio_cleanup()
}

game_app_make :: proc() -> eng.Game_App {
	return eng.Game_App {
		name     = "Into the Depths",
		init     = game_app_init,
		update   = game_app_update,
		render   = game_app_render,
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
	state.content = content_manager_make()
	state.saves = save_manager_make()
	app.state = state

	if !content_manager_load_all(&state.content) {
		logger_fatalf(.App, "Failed to load data files. Exiting.")
		free(state)
		app.state = nil
		return false
	}

	state.game = game_init()
	if !game_scene_manager_init(&state.scene_manager, state.scene_descriptors[:], state.game) {
		logger_fatalf(.App, "Failed to initialize scene manager. Exiting.")
		game_destroy(state.game)
		free(state)
		app.state = nil
		return false
	}

	game := state.game
	logger_debugf(.Init, "seed = %v", game.seed)

	compute_fov(game)
	camera_update(game, snap = true)
	add_message(game, "Welcome to the depths. Tread carefully...", rl.Color{200, 200, 100, 255})

	return true
}

game_app_update :: proc(engine: ^eng.Engine, app: ^eng.Game_App) -> bool {
	state := game_app_state(app)
	if state == nil || state.game == nil {
		return true
	}

	game := state.game
	handle_global_input(game, &game.input)
	return game_scene_manager_update(&state.scene_manager, game)
}

game_app_render :: proc(engine: ^eng.Engine, app: ^eng.Game_App) {
	state := game_app_state(app)
	if state == nil || state.game == nil {
		return
	}
	game_scene_manager_render(&state.scene_manager, state.game)
}

game_app_autosave :: proc(engine: ^eng.Engine, app: ^eng.Game_App) {
	state := game_app_state(app)
	if state == nil || state.game == nil {
		return
	}

	if state.game.state == .Playing {
		save_manager_save_game(&state.saves, state.game)
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
	free(state)
	app.state = nil
}
