package main

import "core:testing"
import eng "./engine"

@(test)
input_manager_make_applies_default_repeat_settings :: proc(t: ^testing.T) {
	input := input_manager_make()

	testing.expect_value(t, input.repeat_delay, KEY_REPEAT_DELAY)
	testing.expect_value(t, input.repeat_rate, KEY_REPEAT_RATE)
	testing.expect(t, input.bindings[.Move_North].primary != .KEY_NULL)
}

@(test)
input_manager_fits_engine_service_storage :: proc(t: ^testing.T) {
	testing.expect(t, size_of(Input_Manager) <= eng.ENGINE_SERVICE_STORAGE_BYTES)
}
