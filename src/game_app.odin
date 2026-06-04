package main

import eng "./engine"
import "core:strconv"

// ─── Into the Depths app adapter ─────────────────────────────────────────────

GAME_ENGINE_SERVICE_CONTENT :: eng.Engine_Service_Id(1)
GAME_ENGINE_SERVICE_SAVES :: eng.Engine_Service_Id(2)
GAME_ENGINE_SERVICE_AUDIO :: eng.Engine_Service_Id(3)
GAME_ENGINE_SERVICE_SPRITES :: eng.Engine_Service_Id(4)
GAME_ENGINE_SERVICE_PARTICLES :: eng.Engine_Service_Id(5)
GAME_ENGINE_SERVICE_SCORES :: eng.Engine_Service_Id(6)
GAME_ENGINE_SERVICE_INPUT :: eng.Engine_Service_Id(7)
GAME_ENGINE_SERVICE_MESSAGES :: eng.Engine_Service_Id(8)
GAME_ENGINE_SERVICE_CAMERA :: eng.Engine_Service_Id(9)
GAME_ENGINE_SERVICE_TURNS :: eng.Engine_Service_Id(10)
GAME_ENGINE_SERVICE_VFX :: eng.Engine_Service_Id(11)
GAME_ENGINE_SERVICE_UI :: eng.Engine_Service_Id(12)

Into_The_Depths_App_State :: struct {
	game:              ^Game,
	scene_descriptors: [GAME_SCENE_COUNT]eng.Engine_Scene,
}

g_config: eng.Config_Manager

Game_Config :: struct {
	master_volume: f32,
	music_volume:  f32,
}

g_game_config: Game_Config

game_engine_config :: proc() -> eng.Engine_Config {
	config := eng.engine_config_make(SCREEN_WIDTH, SCREEN_HEIGHT, "Into the Depths", 60)
	when ODIN_OS == .JS {
		// Web: karl2d backends, nil audio (no music streaming on web yet)
		config.platform = karl2d_platform_backend()
		config.render = karl2d_render_backend()
		config.input = karl2d_input_backend()
		config.texture = karl2d_texture_backend()
	} else {
		// Desktop: Raylib defaults + game audio backend
		config.audio = game_audio_backend(&g_audio)
	}
	return config
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
	g_config = eng.config_manager_make()
	eng.config_manager_load_env_file(&g_config, ".env")
	logger_init_from_config(&g_logger, &g_config)

	if v, ok := strconv.parse_f32(eng.config_manager_get_or(&g_config, "ITD_MASTER_VOLUME", ""));
	   ok && v > 0 {
		g_game_config.master_volume = v
	} else {
		g_game_config.master_volume = 0.7
	}
	if v, ok := strconv.parse_f32(eng.config_manager_get_or(&g_config, "ITD_MUSIC_VOLUME", ""));
	   ok && v > 0 {
		g_game_config.music_volume = v
	} else {
		g_game_config.music_volume = 0.3
	}
}

game_diagnostics_shutdown :: proc() {
	logger_destroy(&g_logger)
}

game_runtime_assets_init :: proc() {
	when ODIN_OS != .JS {
		backend := game_audio_backend(&g_audio)
		audio_init(backend)
		music_init()
		audio_set_master_volume(g_game_config.master_volume)
		music_set_volume(g_game_config.music_volume)
	}
}

game_runtime_assets_shutdown :: proc() {
	when ODIN_OS != .JS {
		music_cleanup()
		audio_cleanup()
	}
}

game_engine_register_app_services :: proc(engine: ^eng.Engine) -> bool {
	if engine == nil || engine.services == nil {
		return false
	}
	content := content_manager_make()
	// Data is #load'd at compile time — no storage backend needed.
	saves := save_manager_make()
	saves.storage = eng.storage_manager_make(eng.engine_file_system(engine))
	sprites := sprite_manager_make()
	scores := score_manager_make()
	scores.storage = eng.storage_manager_make(eng.engine_file_system(engine))
	input := input_manager_make()
	input.backend = eng.engine_input_backend(engine)
	ui := ui_manager_make(g_sprites.loaded)
	return(
		eng.engine_services_register_value(
			engine.services,
			GAME_ENGINE_SERVICE_CONTENT,
			&content,
			size_of(Content_Manager),
		) !=
			nil &&
		eng.engine_services_register_value(
			engine.services,
			GAME_ENGINE_SERVICE_SAVES,
			&saves,
			size_of(Save_Manager),
		) !=
			nil &&
		eng.engine_services_register_value(
			engine.services,
			GAME_ENGINE_SERVICE_SPRITES,
			&sprites,
			size_of(Sprite_Manager),
		) !=
			nil &&
		eng.engine_services_register_value(
			engine.services,
			GAME_ENGINE_SERVICE_SCORES,
			&scores,
			size_of(Score_Manager),
		) !=
			nil &&
		eng.engine_services_register_value(
			engine.services,
			GAME_ENGINE_SERVICE_INPUT,
			&input,
			size_of(Input_Manager),
		) !=
			nil &&
		eng.engine_services_register_value(
			engine.services,
			GAME_ENGINE_SERVICE_UI,
			&ui,
			size_of(UI_Manager),
		) !=
			nil \
	)
}

game_engine_content_manager :: proc(engine: ^eng.Engine) -> ^Content_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return(
		cast(^Content_Manager)eng.engine_services_get(
			engine.services,
			GAME_ENGINE_SERVICE_CONTENT,
		) \
	)
}

game_engine_save_manager :: proc(engine: ^eng.Engine) -> ^Save_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return cast(^Save_Manager)eng.engine_services_get(engine.services, GAME_ENGINE_SERVICE_SAVES)
}

game_engine_audio_manager :: proc(engine: ^eng.Engine) -> ^Audio_Manager {
	return eng.engine_audio_manager(engine)
}

game_engine_sprite_manager :: proc(engine: ^eng.Engine) -> ^Sprite_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return(
		cast(^Sprite_Manager)eng.engine_services_get(
			engine.services,
			GAME_ENGINE_SERVICE_SPRITES,
		) \
	)
}

game_engine_particle_manager :: proc(engine: ^eng.Engine) -> ^Particle_Manager {
	return eng.engine_particle_manager(engine)
}

game_engine_score_manager :: proc(engine: ^eng.Engine) -> ^Score_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return cast(^Score_Manager)eng.engine_services_get(engine.services, GAME_ENGINE_SERVICE_SCORES)
}

game_engine_input_manager :: proc(engine: ^eng.Engine) -> ^Input_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return cast(^Input_Manager)eng.engine_services_get(engine.services, GAME_ENGINE_SERVICE_INPUT)
}

game_engine_message_manager :: proc(engine: ^eng.Engine) -> ^Message_Manager {
	return eng.engine_message_manager(engine)
}

game_engine_camera_manager :: proc(engine: ^eng.Engine) -> ^eng.Camera_Manager {
	return eng.engine_camera_manager(engine)
}

game_engine_turn_manager :: proc(engine: ^eng.Engine) -> ^eng.Turn_Manager {
	return eng.engine_turn_manager(engine)
}

game_engine_vfx_manager :: proc(engine: ^eng.Engine) -> ^eng.Vfx_Manager {
	return eng.engine_vfx_manager(engine)
}

game_engine_ui_manager :: proc(engine: ^eng.Engine) -> ^UI_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return cast(^UI_Manager)eng.engine_services_get(engine.services, GAME_ENGINE_SERVICE_UI)
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

	sprites_init(engine)

	if !game_engine_register_app_services(engine) {
		logger_fatalf(.App, "Failed to register app services. Exiting.")
		sprites_cleanup(engine)
		free(state)
		app.state = nil
		return false
	}

	content := game_engine_content_manager(engine)
	if content == nil || !content_manager_load_all(content) {
		logger_fatalf(.App, "Failed to load data files. Exiting.")
		sprites_cleanup(engine)
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
		sprites_cleanup(engine)
		free(state)
		app.state = nil
		return false
	}

	game := state.game
	logger_debugf(.Init, "seed = %v", game.seed)

	compute_fov(game)
	game_camera_update(game_engine_camera_manager(engine), game, true)
	add_message(
		game_engine_message_manager(engine),
		game,
		"Welcome to the depths. Tread carefully...",
		eng.Engine_Color{200, 200, 100, 255},
	)

	return true
}

game_app_update :: proc(engine: ^eng.Engine, app: ^eng.Game_App) -> bool {
	state := game_app_state(app)
	if state == nil || state.game == nil {
		return true
	}

	game := state.game
	music_update(game)
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
	sprites_cleanup(engine)
	free(state)
	app.state = nil
}
