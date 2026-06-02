package engine

import "core:testing"

@(test)
engine_config_make_uses_requested_window_settings :: proc(t: ^testing.T) {
	config := engine_config_make(1280, 720, "Test Window", 144)

	testing.expect_value(t, config.window_width, 1280)
	testing.expect_value(t, config.window_height, 720)
	testing.expect(t, string(config.window_title) == "Test Window")
	testing.expect_value(t, config.target_fps, 144)
}

@(test)
game_app_callbacks_are_initialized :: proc(t: ^testing.T) {
	app := Game_App {
		name     = "Test App",
		init     = test_app_init,
		update   = test_app_update,
		render   = test_app_render,
		shutdown = test_app_shutdown,
		autosave = test_app_autosave,
	}

	testing.expect(t, app.init != nil)
	testing.expect(t, app.update != nil)
	testing.expect(t, app.render != nil)
	testing.expect(t, app.shutdown != nil)
	testing.expect(t, app.autosave != nil)
	testing.expect_value(t, app.name, "Test App")
}

test_app_init :: proc(engine: ^Engine, app: ^Game_App) -> bool {return true}
test_app_update :: proc(engine: ^Engine, app: ^Game_App) -> bool {return false}
test_app_render :: proc(engine: ^Engine, app: ^Game_App) {}
test_app_shutdown :: proc(engine: ^Engine, app: ^Game_App) {}
test_app_autosave :: proc(engine: ^Engine, app: ^Game_App) {}
