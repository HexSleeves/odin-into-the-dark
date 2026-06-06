#+build !js
package engine

import "core:testing"

@(test)
action_input_manager_reads_configured_bindings_from_backend :: proc(t: ^testing.T) {
	state := Test_Action_Input_Backend_State{}
	state.pressed[Engine_Key.W] = true
	state.pressed[Engine_Key.Slash] = true
	state.down[Engine_Key.Left_Shift] = true
	input := action_input_manager_make(0.20, 0.08)
	input.backend = test_action_input_backend(&state)
	action_input_manager_set_binding(&input, 0, Engine_Key_Binding{primary = .W})
	action_input_manager_set_binding(
		&input,
		1,
		Engine_Key_Binding{primary = .Slash, needs_shift = true},
	)
	action_input_manager_set_binding(&input, 2, Engine_Key_Binding{primary = .S})

	testing.expect(t, action_input_pressed(&input, 0))
	testing.expect(t, action_input_pressed(&input, 1))
	testing.expect(t, !action_input_pressed(&input, 2))
}

@(test)
action_input_manager_prefers_shifted_binding_over_unshifted_binding_for_same_key :: proc(
	t: ^testing.T,
) {
	state := Test_Action_Input_Backend_State{}
	state.pressed[Engine_Key.C] = true
	state.down[Engine_Key.C] = true
	state.released[Engine_Key.C] = true
	state.down[Engine_Key.Left_Shift] = true
	input := action_input_manager_make(0.20, 0.08)
	input.backend = test_action_input_backend(&state)
	action_input_manager_set_binding(&input, 0, Engine_Key_Binding{primary = .C})
	action_input_manager_set_binding(
		&input,
		1,
		Engine_Key_Binding{primary = .C, needs_shift = true},
	)

	testing.expect(t, !action_input_pressed(&input, 0))
	testing.expect(t, !action_input_held(&input, 0))
	testing.expect(t, !action_input_released(&input, 0))
	testing.expect(t, action_input_pressed(&input, 1))
	testing.expect(t, action_input_held(&input, 1))
	testing.expect(t, action_input_released(&input, 1))
}

@(test)
action_input_manager_fires_shifted_binding_when_shift_is_pressed_after_primary_key :: proc(
	t: ^testing.T,
) {
	state := Test_Action_Input_Backend_State{}
	state.down[Engine_Key.C] = true
	state.pressed[Engine_Key.Left_Shift] = true
	state.down[Engine_Key.Left_Shift] = true
	input := action_input_manager_make(0.20, 0.08)
	input.backend = test_action_input_backend(&state)
	action_input_manager_set_binding(
		&input,
		0,
		Engine_Key_Binding{primary = .C, needs_shift = true},
	)

	testing.expect(t, action_input_pressed(&input, 0))
}

@(test)
action_input_manager_reads_released_and_held_alternate_keys :: proc(t: ^testing.T) {
	state := Test_Action_Input_Backend_State{}
	state.down[Engine_Key.Up] = true
	state.released[Engine_Key.Space] = true
	input := action_input_manager_make(0.20, 0.08)
	input.backend = test_action_input_backend(&state)
	action_input_manager_set_binding(&input, 0, Engine_Key_Binding{primary = .W, alt = .Up})
	action_input_manager_set_binding(&input, 1, Engine_Key_Binding{primary = .Enter, alt = .Space})

	testing.expect(t, action_input_held(&input, 0))
	testing.expect(t, action_input_released(&input, 1))
}

@(test)
action_input_manager_repeat_uses_backend_frame_time :: proc(t: ^testing.T) {
	state := Test_Action_Input_Backend_State {
		frame_time = 0.28,
	}
	state.down[Engine_Key.W] = true
	input := action_input_manager_make(0.20, 0.08)
	input.backend = test_action_input_backend(&state)
	action_input_manager_set_binding(&input, 0, Engine_Key_Binding{primary = .W})

	testing.expect(t, action_input_repeat(&input, 0))
	testing.expect(t, action_input_repeat(&input, 0))

	state.down[Engine_Key.W] = false
	testing.expect(t, !action_input_repeat(&input, 0))
	testing.expect_value(t, input.repeat[0].hold_time, f32(0))
}

Test_Action_Input_Backend_State :: struct {
	pressed:    [Engine_Key]bool,
	down:       [Engine_Key]bool,
	released:   [Engine_Key]bool,
	frame_time: f32,
}

test_action_input_backend :: proc(
	state: ^Test_Action_Input_Backend_State,
) -> Engine_Input_Backend {
	return Engine_Input_Backend {
		ctx = state,
		key_down = test_action_input_key_down,
		key_pressed = test_action_input_key_pressed,
		key_released = test_action_input_key_released,
		frame_time = test_action_input_frame_time,
		mouse_position = test_action_input_mouse_position,
		mouse_button_down = test_action_input_mouse_button_down,
		mouse_button_released = test_action_input_mouse_button_released,
		scroll_delta = test_action_input_scroll_delta,
	}
}

test_action_input_key_down :: proc(ctx: rawptr, key: Engine_Key) -> bool {
	state := cast(^Test_Action_Input_Backend_State)ctx
	return state.down[key]
}

test_action_input_key_pressed :: proc(ctx: rawptr, key: Engine_Key) -> bool {
	state := cast(^Test_Action_Input_Backend_State)ctx
	return state.pressed[key]
}

test_action_input_key_released :: proc(ctx: rawptr, key: Engine_Key) -> bool {
	state := cast(^Test_Action_Input_Backend_State)ctx
	return state.released[key]
}

test_action_input_frame_time :: proc(ctx: rawptr) -> f32 {
	state := cast(^Test_Action_Input_Backend_State)ctx
	return state.frame_time
}

test_action_input_mouse_position :: proc(ctx: rawptr) -> Engine_Mouse_Position {
	return {}
}

test_action_input_mouse_button_down :: proc(ctx: rawptr, button: Engine_Mouse_Button) -> bool {
	return false
}

test_action_input_mouse_button_released :: proc(ctx: rawptr, button: Engine_Mouse_Button) -> bool {
	return false
}

test_action_input_scroll_delta :: proc(ctx: rawptr) -> f32 {
	return 0
}
