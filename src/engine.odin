package main

import rl "vendor:raylib"

// ─── Engine runtime boundary ─────────────────────────────────────────────────

Engine_Config :: struct {
	window_width:  i32,
	window_height: i32,
	window_title:  cstring,
	target_fps:    i32,
}

Engine :: struct {
	config: Engine_Config,
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

engine_default_config :: proc() -> Engine_Config {
	return Engine_Config {
		window_width  = SCREEN_WIDTH,
		window_height = SCREEN_HEIGHT,
		window_title  = "Into the Depths",
		target_fps    = 60,
	}
}

engine_run :: proc(config: Engine_Config, app: ^Game_App) {
	engine := Engine{config = config}

	logger_init_from_env(&g_logger)
	defer logger_destroy(&g_logger)

	rl.InitWindow(config.window_width, config.window_height, config.window_title)
	defer rl.CloseWindow()
	rl.SetTargetFPS(config.target_fps)

	audio_init()
	defer audio_cleanup()

	sprites_init()
	defer sprites_cleanup()

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
