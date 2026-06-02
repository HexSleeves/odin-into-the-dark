package main

import rl "vendor:raylib"
import eng "./engine"

// ─── Into the Depths app adapter ─────────────────────────────────────────────

GAME_ENGINE_SERVICE_CONTENT :: eng.Engine_Service_Id(1)
GAME_ENGINE_SERVICE_SAVES :: eng.Engine_Service_Id(2)
GAME_ENGINE_SERVICE_AUDIO :: eng.Engine_Service_Id(3)
GAME_ENGINE_SERVICE_SPRITES :: eng.Engine_Service_Id(4)

Into_The_Depths_App_State :: struct {
	game:              ^Game,
	content:           Content_Manager,
	saves:             Save_Manager,
	audio:             Audio_Manager,
	sprites:           Sprite_Manager,
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

game_engine_register_app_services :: proc(engine: ^eng.Engine, state: ^Into_The_Depths_App_State) -> bool {
	if engine == nil || engine.services == nil || state == nil {
		return false
	}
	return eng.engine_services_register(engine.services, GAME_ENGINE_SERVICE_CONTENT, rawptr(&state.content)) &&
	       eng.engine_services_register(engine.services, GAME_ENGINE_SERVICE_SAVES, rawptr(&state.saves)) &&
	       eng.engine_services_register(engine.services, GAME_ENGINE_SERVICE_AUDIO, rawptr(&state.audio)) &&
	       eng.engine_services_register(engine.services, GAME_ENGINE_SERVICE_SPRITES, rawptr(&state.sprites))
}

game_engine_content_manager :: proc(engine: ^eng.Engine) -> ^Content_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return cast(^Content_Manager)eng.engine_services_get(engine.services, GAME_ENGINE_SERVICE_CONTENT)
}

game_engine_save_manager :: proc(engine: ^eng.Engine) -> ^Save_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return cast(^Save_Manager)eng.engine_services_get(engine.services, GAME_ENGINE_SERVICE_SAVES)
}

game_engine_audio_manager :: proc(engine: ^eng.Engine) -> ^Audio_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return cast(^Audio_Manager)eng.engine_services_get(engine.services, GAME_ENGINE_SERVICE_AUDIO)
}

game_engine_sprite_manager :: proc(engine: ^eng.Engine) -> ^Sprite_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return cast(^Sprite_Manager)eng.engine_services_get(engine.services, GAME_ENGINE_SERVICE_SPRITES)
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
	state.audio = audio_manager_make()
	state.sprites = sprite_manager_make()
	app.state = state

	if !game_engine_register_app_services(engine, state) {
		logger_fatalf(.App, "Failed to register app services. Exiting.")
		free(state)
		app.state = nil
		return false
	}

	content := game_engine_content_manager(engine)
	if content == nil || !content_manager_load_all(content) {
		logger_fatalf(.App, "Failed to load data files. Exiting.")
		free(state)
		app.state = nil
		return false
	}

	state.game = game_init()
	if !game_scene_manager_init(&state.scene_manager, state.scene_descriptors[:], engine, state.game) {
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
	handle_global_input(engine, game, &game.input)
	return game_scene_manager_update(&state.scene_manager, engine, game)
}

game_app_render :: proc(engine: ^eng.Engine, app: ^eng.Game_App) {
	state := game_app_state(app)
	if state == nil || state.game == nil {
		return
	}
	game_scene_manager_render(&state.scene_manager, engine, state.game)
}

game_app_autosave :: proc(engine: ^eng.Engine, app: ^eng.Game_App) {
	state := game_app_state(app)
	if state == nil || state.game == nil {
		return
	}

	saves := game_engine_save_manager(engine)
	if state.game.state == .Playing && saves != nil {
		save_manager_save_game(saves, state.game)
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
