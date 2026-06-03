// Web entry point skeleton for js_wasm32 builds.
//
// STATUS: NOT USED by the current build.
//
// The standard build (`odin build src/ -target:js_wasm32 -build-mode:obj`)
// compiles package main from src/, which calls engine_run(). Raylib's
// WASM variant (vendor/raylib/wasm/libraylib.a) is compiled with emscripten
// and handles the event loop internally — the blocking `for !WindowShouldClose`
// loop in engine_run works correctly once linked via emcc. No restructuring is
// required for the initial web release.
//
// WHY THIS FILE EXISTS
//
// If the blocking-loop approach ever breaks (e.g. asyncify overhead, memory
// pressure, or a need for explicit frame budgeting), the correct fix is to
// restructure the game loop into init/step/end procs exported from WASM.
// This file is the starting point for that restructure.
//
// HOW IT WOULD WORK
//
// 1. Build this package instead of src/:
//      odin build src/main_web/ -target:js_wasm32 -build-mode:obj \
//          -define:RAYLIB_WASM_LIB=env.o -out:build/web/game.wasm.o
//
// 2. Odin's odin.js runtime will call the exported @export procs below
//    from JavaScript rather than running a top-level main().
//
// LIMITATION
//
// This package cannot import `package main` (src/*.odin) because Odin
// does not allow importing a main package. To use this pattern, the game
// logic must be extracted into an importable sub-package (e.g. src/game/).
// That refactor is tracked separately and is out of scope for v0.1.0.
package main_web

import eng "../engine"
import rl "vendor:raylib"

// State held across frames. Populated in web_start(), consumed in web_step().
@(private)
_engine: eng.Engine

@(private)
_app: eng.Game_App

// web_start is called once when the WASM module initialises.
// Mirrors the setup phase of engine_run() without starting the frame loop.
@(export)
web_start :: proc() {
	// TODO: replace with real config/services once the game package is extracted
	// from package main into an importable sub-package.
	//
	// config   := game.engine_config()
	// services := game.engine_services_config()
	// _app      = game.app_make()
	// ... engine init ...
	_ = _engine
	_ = _app
}

// web_step is called once per animation frame by odin.js.
// Returns false to signal shutdown (e.g. player quit via ESC).
@(export)
web_step :: proc(dt: f32) -> bool {
	if rl.WindowShouldClose() {
		return false
	}

	// TODO: call _app.update + _app.render once game package is importable.
	return true
}

// web_end is called when the WASM module is torn down.
@(export)
web_end :: proc() {
	// TODO: call _app.shutdown and engine cleanup once game package is importable.
}
