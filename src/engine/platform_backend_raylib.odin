#+build !js
package engine

import rl "vendor:raylib"

// Raylib platform backend — desktop default. Excluded from the JS/WASM build,
// which cannot link libraylib.a; web uses the karl2d platform backend instead.

engine_platform_backend_raylib :: proc() -> Engine_Platform_Backend {
	return Engine_Platform_Backend {
		init = raylib_platform_init,
		shutdown = raylib_platform_shutdown,
		set_target_fps = raylib_platform_set_target_fps,
		disable_exit_key = raylib_platform_disable_exit_key,
		window_should_close = raylib_platform_window_should_close,
	}
}

@(private = "file")
raylib_platform_init :: proc(ctx: rawptr, config: Engine_Config) -> bool {
	rl.InitWindow(config.window_width, config.window_height, config.window_title)
	return true
}

@(private = "file")
raylib_platform_shutdown :: proc(ctx: rawptr) {
	rl.CloseWindow()
}

@(private = "file")
raylib_platform_set_target_fps :: proc(ctx: rawptr, target_fps: i32) {
	rl.SetTargetFPS(target_fps)
}

@(private = "file")
raylib_platform_disable_exit_key :: proc(ctx: rawptr) {
	rl.SetExitKey(rl.KeyboardKey.KEY_NULL)
}

@(private = "file")
raylib_platform_window_should_close :: proc(ctx: rawptr) -> bool {
	return rl.WindowShouldClose()
}
