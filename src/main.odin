package main

import eng "./engine"

// ─── Entry point ──────────────────────────────────────────────────────────────

main :: proc() {
	config := game_engine_config()
	services := game_engine_services_config()
	app := game_app_make()
	eng.engine_run(config, services, &app)
}
