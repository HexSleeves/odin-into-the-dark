package engine

import "core:testing"

@(test)
engine_services_default_config_has_no_game_callbacks :: proc(t: ^testing.T) {
	config := engine_services_default_config()

	testing.expect(t, config.diagnostics_init == nil)
	testing.expect(t, config.diagnostics_shutdown == nil)
	testing.expect(t, config.runtime_assets_init == nil)
	testing.expect(t, config.runtime_assets_shutdown == nil)
}

@(test)
engine_services_make_starts_uninitialized :: proc(t: ^testing.T) {
	services := engine_services_make(engine_services_default_config())

	testing.expect(t, !services.diagnostics_initialized)
	testing.expect(t, !services.runtime_assets_initialized)
}

@(private = "file")
engine_services_test_counter: int

@(private = "file")
engine_services_test_callback :: proc() {
	engine_services_test_counter += 1
}

@(test)
engine_services_lifecycle_invokes_configured_callbacks :: proc(t: ^testing.T) {
	engine_services_test_counter = 0
	services := engine_services_make(
		Engine_Services_Config {
			diagnostics_init = engine_services_test_callback,
			diagnostics_shutdown = engine_services_test_callback,
			runtime_assets_init = engine_services_test_callback,
			runtime_assets_shutdown = engine_services_test_callback,
		},
	)

	engine_services_init_diagnostics(&services)
	engine_services_init_runtime_assets(&services)
	testing.expect(t, services.diagnostics_initialized)
	testing.expect(t, services.runtime_assets_initialized)
	testing.expect_value(t, engine_services_test_counter, 2)

	engine_services_shutdown_runtime_assets(&services)
	engine_services_shutdown_diagnostics(&services)
	testing.expect(t, !services.diagnostics_initialized)
	testing.expect(t, !services.runtime_assets_initialized)
	testing.expect_value(t, engine_services_test_counter, 4)
}
