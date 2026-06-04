#+build js
package main

import eng "./engine"
import "base:runtime"

// Desktop-only procs that need no-op stubs on web.
_set_bundle_working_dir :: proc() {}

// ─── Web entry point ─────────────────────────────────────────────────────────
// karl2d's JS runtime calls _start (→ main), then step() each frame.
// We use engine_init/engine_step/engine_shutdown instead of the blocking engine_run.

@(private = "file")
_web_state: eng.Engine_State

@(private = "file")
_web_app: eng.Game_App

@(private = "file")
_web_ctx: runtime.Context

@(export)
step :: proc(dt: f64) -> bool {
	context = _web_ctx
	return eng.engine_step(&_web_state)
}

@(export)
shutdown :: proc(dt: f64) {
	context = _web_ctx
	eng.engine_shutdown(&_web_state)
}

// main is called by _start from odin.js. Sets up and inits the engine.
// After main returns, the JS runtime calls step() each animation frame.
web_main_init :: proc() {
	_web_ctx = context
	config := game_engine_config()
	services := game_engine_services_config()
	_web_app = game_app_make()
	if !eng.engine_init(&_web_state, config, services, &_web_app) {
		eng.engine_shutdown(&_web_state)
	}
}
