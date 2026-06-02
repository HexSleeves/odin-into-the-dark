package main

// ─── Entry point ──────────────────────────────────────────────────────────────

main :: proc() {
	config := engine_default_config()
	app := game_app_make()
	engine_run(config, &app)
}
