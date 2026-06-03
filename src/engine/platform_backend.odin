package engine

// Engine platform backend boundary.
//
// The default backend is Raylib, but engine_run only depends on this contract.
// Tests and future ports can provide a small backend without opening a window.
Engine_Platform_Backend :: struct {
	ctx:                 rawptr,
	init:                proc(ctx: rawptr, config: Engine_Config) -> bool,
	shutdown:            proc(ctx: rawptr),
	set_target_fps:      proc(ctx: rawptr, target_fps: i32),
	disable_exit_key:    proc(ctx: rawptr),
	window_should_close: proc(ctx: rawptr) -> bool,
}

engine_platform_backend_is_valid :: proc(platform: Engine_Platform_Backend) -> bool {
	return(
		platform.init != nil &&
		platform.shutdown != nil &&
		platform.set_target_fps != nil &&
		platform.disable_exit_key != nil &&
		platform.window_should_close != nil \
	)
}

engine_platform_backend_or_default :: proc(
	platform: Engine_Platform_Backend,
) -> Engine_Platform_Backend {
	if engine_platform_backend_is_valid(platform) {
		return platform
	}
	// Raylib on desktop (platform_backend_raylib.odin); nil on JS, where Raylib
	// cannot link and the game injects the karl2d platform backend.
	when ODIN_OS == .JS {
		return engine_platform_backend_nil()
	} else {
		return engine_platform_backend_raylib()
	}
}

engine_platform_backend_nil :: proc() -> Engine_Platform_Backend {
	return Engine_Platform_Backend {
		init = nil_platform_init,
		shutdown = nil_platform_shutdown,
		set_target_fps = nil_platform_set_target_fps,
		disable_exit_key = nil_platform_disable_exit_key,
		window_should_close = nil_platform_window_should_close,
	}
}

@(private = "file")
nil_platform_init :: proc(ctx: rawptr, config: Engine_Config) -> bool {
	return true
}

@(private = "file")
nil_platform_shutdown :: proc(ctx: rawptr) {}

@(private = "file")
nil_platform_set_target_fps :: proc(ctx: rawptr, target_fps: i32) {}

@(private = "file")
nil_platform_disable_exit_key :: proc(ctx: rawptr) {}

@(private = "file")
nil_platform_window_should_close :: proc(ctx: rawptr) -> bool {
	return true
}
