#+build !js
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

@(test)
engine_services_registers_and_replaces_service_contexts :: proc(t: ^testing.T) {
	services := engine_services_make(engine_services_default_config())
	first: int = 11
	second: int = 22

	testing.expect(t, engine_services_register(&services, 7, rawptr(&first)))
	testing.expect(t, engine_services_has(&services, 7))
	testing.expect(t, engine_services_get(&services, 7) == rawptr(&first))

	testing.expect(t, engine_services_register(&services, 7, rawptr(&second)))
	testing.expect(t, engine_services_get(&services, 7) == rawptr(&second))
	testing.expect_value(t, services.service_count, 1)
}

@(test)
engine_services_registers_engine_owned_service_values :: proc(t: ^testing.T) {
	services := engine_services_make(engine_services_default_config())
	defer engine_services_destroy(&services)
	value: i32 = 42

	stored := cast(^i32)engine_services_register_value(&services, 8, &value, size_of(i32))
	testing.expect(t, stored != nil)
	testing.expect(t, stored != &value)
	testing.expect_value(t, stored^, 42)
	testing.expect(t, engine_services_get(&services, 8) == rawptr(stored))

	value = 7
	testing.expect_value(t, stored^, 42)

	replacement: i32 = 99
	replaced := cast(^i32)engine_services_register_value(&services, 8, &replacement, size_of(i32))
	testing.expect(t, replaced == stored)
	testing.expect_value(t, replaced^, 99)
	testing.expect_value(t, services.service_count, 1)
}

@(test)
engine_services_rejects_oversized_engine_owned_values :: proc(t: ^testing.T) {
	services := engine_services_make(engine_services_default_config())
	defer engine_services_destroy(&services)
	too_large: [ENGINE_SERVICE_STORAGE_BYTES + 1]u8

	testing.expect(
		t,
		engine_services_register_value(&services, 9, &too_large, size_of(type_of(too_large))) ==
		nil,
	)
	testing.expect(t, !engine_services_has(&services, 9))
}

@(test)
engine_services_rejects_invalid_or_overflow_registrations :: proc(t: ^testing.T) {
	services := engine_services_make(engine_services_default_config())

	testing.expect(t, !engine_services_register(nil, 1, rawptr(uintptr(1))))
	testing.expect(t, !engine_services_register(&services, -1, rawptr(uintptr(1))))
	testing.expect(t, !engine_services_has(&services, -1))
	testing.expect(t, engine_services_get(&services, -1) == nil)

	for i in 0 ..< ENGINE_SERVICE_MAX {
		testing.expect(
			t,
			engine_services_register(&services, Engine_Service_Id(i), rawptr(uintptr(i + 1))),
		)
	}
	testing.expect(
		t,
		!engine_services_register(
			&services,
			Engine_Service_Id(ENGINE_SERVICE_MAX + 1),
			rawptr(uintptr(99)),
		),
	)
}
