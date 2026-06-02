package engine

import rl "vendor:raylib"

// ─── Engine runtime boundary ─────────────────────────────────────────────────

Engine_Config :: struct {
	window_width:  i32,
	window_height: i32,
	window_title:  cstring,
	target_fps:    i32,
}

Engine :: struct {
	config:        Engine_Config,
	services:      ^Engine_Services,
	scene_manager: Scene_Manager,
}

Game_App :: struct {
	name:     string,
	state:    rawptr,
	init:     proc(engine: ^Engine, app: ^Game_App) -> bool,
	update:   proc(engine: ^Engine, app: ^Game_App) -> bool,
	render:   proc(engine: ^Engine, app: ^Game_App),
	shutdown: proc(engine: ^Engine, app: ^Game_App),
	autosave: proc(engine: ^Engine, app: ^Game_App),
}

engine_config_make :: proc(
	window_width: i32,
	window_height: i32,
	window_title: cstring,
	target_fps: i32,
) -> Engine_Config {
	return Engine_Config {
		window_width  = window_width,
		window_height = window_height,
		window_title  = window_title,
		target_fps    = target_fps,
	}
}

engine_scene_manager :: proc(engine: ^Engine) -> ^Scene_Manager {
	if engine == nil {
		return nil
	}
	return &engine.scene_manager
}

engine_run :: proc(config: Engine_Config, services_config: Engine_Services_Config, app: ^Game_App) {
	services := engine_services_make(services_config)
	defer engine_services_destroy(&services)
	engine := Engine{config = config, services = &services}

	engine_services_init_diagnostics(&services)
	defer engine_services_shutdown_diagnostics(&services)

	rl.InitWindow(config.window_width, config.window_height, config.window_title)
	defer rl.CloseWindow()
	rl.SetTargetFPS(config.target_fps)

	engine_services_init_runtime_assets(&services)
	defer engine_services_shutdown_runtime_assets(&services)

	if app == nil || app.init == nil || !app.init(&engine, app) {
		return
	}
	defer app.shutdown(&engine, app)

	// Disable default escape key to allow inventory to be closed with ESC.
	rl.SetExitKey(rl.KeyboardKey.KEY_NULL)

	for !rl.WindowShouldClose() {
		quit := false
		if app.update != nil {
			quit = app.update(&engine, app)
		}
		if quit {
			break
		}

		if app.render != nil {
			app.render(&engine, app)
		}
	}

	if app.autosave != nil {
		app.autosave(&engine, app)
	}
}
