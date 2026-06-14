#+build !js
package engine

import "base:runtime"
import "core:testing"

// Regression lock for the per-frame arena fix (P1): engine_step must point BOTH
// context.allocator and context.temp_allocator at the engine's frame arena for
// the duration of the app update and render callbacks, so transient per-frame
// allocations (tprintf, temp slices) reset every frame instead of leaking on the
// long-lived temp allocator.

Temp_Allocator_Probe_State :: struct {
	update_alloc:    runtime.Allocator,
	update_temp:     runtime.Allocator,
	render_alloc:    runtime.Allocator,
	render_temp:     runtime.Allocator,
	captured_update: bool,
	captured_render: bool,
}

temp_probe_app_update :: proc(engine: ^Engine, app: ^Game_App) -> bool {
	state := cast(^Temp_Allocator_Probe_State)app.state
	state.update_alloc = context.allocator
	state.update_temp = context.temp_allocator
	state.captured_update = true
	return false
}

temp_probe_app_render :: proc(engine: ^Engine, app: ^Game_App) {
	state := cast(^Temp_Allocator_Probe_State)app.state
	state.render_alloc = context.allocator
	state.render_temp = context.temp_allocator
	state.captured_render = true
}

allocators_equal :: proc(a, b: runtime.Allocator) -> bool {
	return a.procedure == b.procedure && a.data == b.data
}

@(test)
engine_step_points_temp_allocator_at_frame_arena_during_update_and_render :: proc(t: ^testing.T) {
	platform_state := Test_Platform_State{}
	app_state := Temp_Allocator_Probe_State{}

	state: Engine_State
	config := engine_config_make(640, 360, "Temp Allocator Probe", 60)
	app := Game_App {
		name   = "Temp Allocator Probe App",
		state  = &app_state,
		init   = test_app_init,
		update = temp_probe_app_update,
		render = temp_probe_app_render,
	}
	config.platform = Engine_Platform_Backend {
		ctx                 = &platform_state,
		init                = test_platform_init,
		shutdown            = test_platform_shutdown,
		set_target_fps      = test_platform_set_target_fps,
		disable_exit_key    = test_platform_disable_exit_key,
		window_should_close = test_platform_window_should_close,
	}

	testing.expect(t, engine_init(&state, config, engine_services_default_config(), &app))
	defer engine_shutdown(&state)

	frame := engine_frame_allocator(&state.engine)

	// One frame: update runs, then (since update returned false) render runs too.
	engine_step(&state)

	testing.expect(t, app_state.captured_update, "update callback must have run")
	testing.expect(t, app_state.captured_render, "render callback must have run")

	testing.expect(
		t,
		allocators_equal(app_state.update_temp, frame),
		"temp_allocator during update must be the engine frame arena",
	)
	testing.expect(
		t,
		allocators_equal(app_state.update_alloc, frame),
		"allocator during update must be the engine frame arena",
	)
	testing.expect(
		t,
		allocators_equal(app_state.render_temp, frame),
		"temp_allocator during render must be the engine frame arena",
	)
	testing.expect(
		t,
		allocators_equal(app_state.render_alloc, frame),
		"allocator during render must be the engine frame arena",
	)
}
