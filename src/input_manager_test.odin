#+build !js
package main

import eng "./engine"
import "core:testing"

@(test)
input_manager_make_applies_default_repeat_settings :: proc(t: ^testing.T) {
	input := input_manager_make()
	engine_input: eng.Action_Input_Manager = input

	testing.expect_value(t, input.repeat_delay, KEY_REPEAT_DELAY)
	testing.expect_value(t, input.repeat_rate, KEY_REPEAT_RATE)
	testing.expect(
		t,
		input.bindings[cast(int)Game_Action.Move_North].primary != eng.Engine_Key.None,
	)
	testing.expect_value(t, engine_input.repeat_delay, KEY_REPEAT_DELAY)
}

@(test)
input_manager_fits_engine_service_storage :: proc(t: ^testing.T) {
	testing.expect(t, size_of(Input_Manager) <= eng.ENGINE_SERVICE_STORAGE_BYTES)
}

@(test)
input_manager_reads_actions_from_configured_engine_input_backend :: proc(t: ^testing.T) {
	backend_state := Test_Input_Backend_State{}
	backend_state.pressed[eng.Engine_Key.W] = true
	backend_state.down[eng.Engine_Key.Left_Shift] = true
	backend_state.pressed[eng.Engine_Key.Slash] = true
	input := input_manager_make()
	input.backend = test_input_backend(&backend_state)

	testing.expect(t, action_pressed(&input, .Move_North))
	testing.expect(t, action_pressed(&input, .Help))
	testing.expect(t, !action_pressed(&input, .Move_South))
}

@(test)
input_manager_repeat_uses_engine_input_frame_time :: proc(t: ^testing.T) {
	backend_state := Test_Input_Backend_State {
		frame_time = KEY_REPEAT_DELAY + KEY_REPEAT_RATE,
	}
	backend_state.down[eng.Engine_Key.W] = true
	input := input_manager_make()
	input.backend = test_input_backend(&backend_state)

	testing.expect(t, check_repeat(&input, .Move_North))
	testing.expect(t, check_repeat(&input, .Move_North))
}

Test_Input_Backend_State :: struct {
	pressed:    [eng.Engine_Key]bool,
	down:       [eng.Engine_Key]bool,
	released:   [eng.Engine_Key]bool,
	frame_time: f32,
}

test_input_backend :: proc(state: ^Test_Input_Backend_State) -> eng.Engine_Input_Backend {
	return eng.Engine_Input_Backend {
		ctx = state,
		key_down = test_input_key_down,
		key_pressed = test_input_key_pressed,
		key_released = test_input_key_released,
		frame_time = test_input_frame_time,
	}
}

test_input_key_down :: proc(ctx: rawptr, key: eng.Engine_Key) -> bool {
	state := cast(^Test_Input_Backend_State)ctx
	return state.down[key]
}

test_input_key_pressed :: proc(ctx: rawptr, key: eng.Engine_Key) -> bool {
	state := cast(^Test_Input_Backend_State)ctx
	return state.pressed[key]
}

test_input_key_released :: proc(ctx: rawptr, key: eng.Engine_Key) -> bool {
	state := cast(^Test_Input_Backend_State)ctx
	return state.released[key]
}

test_input_frame_time :: proc(ctx: rawptr) -> f32 {
	state := cast(^Test_Input_Backend_State)ctx
	return state.frame_time
}