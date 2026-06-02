package main

import "core:testing"

@(test)
engine_default_config_matches_current_window_settings :: proc(t: ^testing.T) {
	config := engine_default_config()

	testing.expect_value(t, config.window_width, SCREEN_WIDTH)
	testing.expect_value(t, config.window_height, SCREEN_HEIGHT)
	testing.expect(t, string(config.window_title) == "Into the Depths")
	testing.expect_value(t, config.target_fps, 60)
}

@(test)
game_app_callbacks_are_initialized :: proc(t: ^testing.T) {
	app := game_app_make()

	testing.expect(t, app.init != nil)
	testing.expect(t, app.update != nil)
	testing.expect(t, app.render != nil)
	testing.expect(t, app.shutdown != nil)
	testing.expect(t, app.autosave != nil)
	testing.expect_value(t, app.name, "Into the Depths")
}
