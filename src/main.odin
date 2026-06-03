package main

import eng "./engine"

// ─── Entry point ──────────────────────────────────────────────────────────────

main :: proc() {
	_set_bundle_working_dir()

	when ODIN_OS == .JS {
		// Web: init only. JS runtime calls step()/shutdown() per frame.
		web_main_init()
	} else {
		// Desktop: blocking game loop.
		config := game_engine_config()
		services := game_engine_services_config()
		app := game_app_make()
		eng.engine_run(config, services, &app)
	}
}
