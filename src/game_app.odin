package main

import rl "vendor:raylib"
import eng "./engine"

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

Into_The_Depths_App_State :: struct {
	game:              ^Game,
	scene_descriptors: [GAME_SCENE_COUNT]eng.Engine_Scene,
}

g_config: eng.Config_Manager

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
	g_config = eng.config_manager_make()
	eng.config_manager_load_env_file(&g_config, ".env")
	logger_init_from_config(&g_logger, &g_config)
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

game_engine_register_app_services :: proc(engine: ^eng.Engine) -> bool {
	if engine == nil || engine.services == nil {
		return false
	}
	content := content_manager_make()
	saves := save_manager_make()
	audio := audio_manager_make()
	sprites := sprite_manager_make()
	particles := particle_manager_make()
	scores := score_manager_make()
	input := input_manager_make()
	messages := message_manager_make()
	camera := eng.camera_manager_make()
	turns := eng.turn_manager_make()
	vfx := eng.vfx_manager_make()
	return eng.engine_services_register_value(engine.services, GAME_ENGINE_SERVICE_CONTENT, &content, size_of(Content_Manager)) != nil &&
	       eng.engine_services_register_value(engine.services, GAME_ENGINE_SERVICE_SAVES, &saves, size_of(Save_Manager)) != nil &&
	       eng.engine_services_register_value(engine.services, GAME_ENGINE_SERVICE_AUDIO, &audio, size_of(Audio_Manager)) != nil &&
	       eng.engine_services_register_value(engine.services, GAME_ENGINE_SERVICE_SPRITES, &sprites, size_of(Sprite_Manager)) != nil &&
	       eng.engine_services_register_value(engine.services, GAME_ENGINE_SERVICE_PARTICLES, &particles, size_of(Particle_Manager)) != nil &&
	       eng.engine_services_register_value(engine.services, GAME_ENGINE_SERVICE_SCORES, &scores, size_of(Score_Manager)) != nil &&
	       eng.engine_services_register_value(engine.services, GAME_ENGINE_SERVICE_INPUT, &input, size_of(Input_Manager)) != nil &&
	       eng.engine_services_register_value(engine.services, GAME_ENGINE_SERVICE_MESSAGES, &messages, size_of(Message_Manager)) != nil &&
	       eng.engine_services_register_value(engine.services, GAME_ENGINE_SERVICE_CAMERA, &camera, size_of(eng.Camera_Manager)) != nil &&
	       eng.engine_services_register_value(engine.services, GAME_ENGINE_SERVICE_TURNS, &turns, size_of(eng.Turn_Manager)) != nil &&
	       eng.engine_services_register_value(engine.services, GAME_ENGINE_SERVICE_VFX, &vfx, size_of(eng.Vfx_Manager)) != nil
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

game_engine_particle_manager :: proc(engine: ^eng.Engine) -> ^Particle_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return cast(^Particle_Manager)eng.engine_services_get(engine.services, GAME_ENGINE_SERVICE_PARTICLES)
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
	if engine == nil || engine.services == nil {
		return nil
	}
	return cast(^Message_Manager)eng.engine_services_get(engine.services, GAME_ENGINE_SERVICE_MESSAGES)
}

game_engine_camera_manager :: proc(engine: ^eng.Engine) -> ^eng.Camera_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return cast(^eng.Camera_Manager)eng.engine_services_get(engine.services, GAME_ENGINE_SERVICE_CAMERA)
}

game_engine_turn_manager :: proc(engine: ^eng.Engine) -> ^eng.Turn_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return cast(^eng.Turn_Manager)eng.engine_services_get(engine.services, GAME_ENGINE_SERVICE_TURNS)
}

game_engine_vfx_manager :: proc(engine: ^eng.Engine) -> ^eng.Vfx_Manager {
	if engine == nil || engine.services == nil {
		return nil
	}
	return cast(^eng.Vfx_Manager)eng.engine_services_get(engine.services, GAME_ENGINE_SERVICE_VFX)
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
	app.state = state

	if !game_engine_register_app_services(engine) {
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

	message_manager_bind_turns(game_engine_message_manager(engine), game_engine_turn_manager(engine))

	state.game = game_init(content)
	if !game_scene_manager_init(state.scene_descriptors[:], engine, state.game) {
		logger_fatalf(.App, "Failed to initialize scene manager. Exiting.")
		game_destroy(state.game)
		free(state)
		app.state = nil
		return false
	}

	game := state.game
	logger_debugf(.Init, "seed = %v", game.seed)

	compute_fov(game)
	game_camera_update(game_engine_camera_manager(engine), game, true)
	add_message(game_engine_message_manager(engine), game, "Welcome to the depths. Tread carefully...", rl.Color{200, 200, 100, 255})

	return true
}

game_app_update :: proc(engine: ^eng.Engine, app: ^eng.Game_App) -> bool {
	state := game_app_state(app)
	if state == nil || state.game == nil {
		return true
	}

	game := state.game
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
	free(state)
	app.state = nil
}
