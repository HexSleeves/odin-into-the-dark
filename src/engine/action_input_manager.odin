package engine

ENGINE_MAX_ACTIONS :: 128

Engine_Key_Binding :: struct {
	primary:     Engine_Key,
	alt:         Engine_Key,
	needs_shift: bool,
}

Engine_Repeat_State :: struct {
	hold_time:    f32,
	repeat_timer: f32,
	last_fired:   bool,
}

Action_Input_Manager :: struct {
	bindings:     [ENGINE_MAX_ACTIONS]Engine_Key_Binding,
	repeat:       [ENGINE_MAX_ACTIONS]Engine_Repeat_State,
	repeat_delay: f32,
	repeat_rate:  f32,
	backend:      Engine_Input_Backend,
}

action_input_manager_make :: proc(repeat_delay, repeat_rate: f32) -> Action_Input_Manager {
	return Action_Input_Manager {
		repeat_delay = repeat_delay,
		repeat_rate = repeat_rate,
		backend = engine_input_backend_default(),
	}
}

action_input_manager_set_binding :: proc(
	input: ^Action_Input_Manager,
	action: int,
	binding: Engine_Key_Binding,
) -> bool {
	if input == nil || !action_input_valid_action(action) {
		return false
	}
	input.bindings[action] = binding
	return true
}

action_input_pressed :: proc(input: ^Action_Input_Manager, action: int) -> bool {
	if input == nil || !action_input_valid_action(action) {
		return false
	}
	backend := action_input_backend(input)
	binding := input.bindings[action]
	if action_input_unshifted_binding_suppressed(input, binding, backend) {return false}
	return action_input_binding_pressed(backend, binding)
}

action_input_held :: proc(input: ^Action_Input_Manager, action: int) -> bool {
	if input == nil || !action_input_valid_action(action) {
		return false
	}
	backend := action_input_backend(input)
	binding := input.bindings[action]
	if action_input_unshifted_binding_suppressed(input, binding, backend) {return false}
	return action_input_binding_held(backend, binding)
}

action_input_released :: proc(input: ^Action_Input_Manager, action: int) -> bool {
	if input == nil || !action_input_valid_action(action) {
		return false
	}
	binding := input.bindings[action]
	backend := action_input_backend(input)
	if action_input_unshifted_binding_suppressed(input, binding, backend) {return false}
	if binding.primary == .None {return false}
	if binding.needs_shift && !action_input_shift_is_held(backend) {return false}
	return(
		engine_input_key_released(backend, binding.primary) ||
		(binding.alt != .None && engine_input_key_released(backend, binding.alt)) \
	)
}

action_input_repeat :: proc(input: ^Action_Input_Manager, action: int) -> bool {
	if input == nil || !action_input_valid_action(action) {
		return false
	}
	backend := action_input_backend(input)
	dt := engine_input_frame_time(backend)
	repeat := &input.repeat[action]
	binding := input.bindings[action]
	held := false
	if !action_input_unshifted_binding_suppressed(input, binding, backend) {
		held = action_input_binding_held(backend, binding)
	}

	if !held {
		repeat.hold_time = 0
		repeat.repeat_timer = 0
		repeat.last_fired = false
		return false
	}

	if !repeat.last_fired {
		repeat.last_fired = true
		repeat.hold_time = 0
		repeat.repeat_timer = 0
		return true
	}

	repeat.hold_time += dt
	if repeat.hold_time < input.repeat_delay {
		return false
	}

	repeat.repeat_timer += dt
	if repeat.repeat_timer >= input.repeat_rate {
		repeat.repeat_timer -= input.repeat_rate
		return true
	}

	return false
}

@(private = "file")
action_input_valid_action :: proc(action: int) -> bool {
	return action >= 0 && action < ENGINE_MAX_ACTIONS
}

@(private = "file")
action_input_backend :: proc(input: ^Action_Input_Manager) -> Engine_Input_Backend {
	if input == nil {
		return engine_input_backend_default()
	}
	return engine_input_backend_or_default(input.backend)
}

@(private = "file")
action_input_unshifted_binding_suppressed :: proc(
	input: ^Action_Input_Manager,
	binding: Engine_Key_Binding,
	backend: Engine_Input_Backend,
) -> bool {
	if input == nil || binding.needs_shift || !action_input_shift_is_held(backend) {
		return false
	}
	for shifted in input.bindings {
		if shifted.needs_shift && action_input_bindings_share_key(binding, shifted) {
			return true
		}
	}
	return false
}

@(private = "file")
action_input_bindings_share_key :: proc(a, b: Engine_Key_Binding) -> bool {
	return(
		a.primary != .None && (a.primary == b.primary || a.primary == b.alt) ||
		a.alt != .None && (a.alt == b.primary || a.alt == b.alt) \
	)
}

@(private = "file")
action_input_binding_held :: proc(
	backend: Engine_Input_Backend,
	binding: Engine_Key_Binding,
) -> bool {
	if binding.primary == .None {return false}
	if binding.needs_shift && !action_input_shift_is_held(backend) {return false}
	return(
		engine_input_key_down(backend, binding.primary) ||
		(binding.alt != .None && engine_input_key_down(backend, binding.alt)) \
	)
}

@(private = "file")
action_input_binding_pressed :: proc(
	backend: Engine_Input_Backend,
	binding: Engine_Key_Binding,
) -> bool {
	if binding.primary == .None {return false}
	if binding.needs_shift {
		if !action_input_shift_is_held(backend) {return false}
		if action_input_shift_pressed(backend) {
			return(
				engine_input_key_down(backend, binding.primary) ||
				(binding.alt != .None && engine_input_key_down(backend, binding.alt)) \
			)
		}
	}
	return(
		engine_input_key_pressed(backend, binding.primary) ||
		(binding.alt != .None && engine_input_key_pressed(backend, binding.alt)) \
	)
}

@(private = "file")
action_input_shift_pressed :: proc(backend: Engine_Input_Backend) -> bool {
	return(
		engine_input_key_pressed(backend, .Left_Shift) ||
		engine_input_key_pressed(backend, .Right_Shift) \
	)
}

@(private = "file")
action_input_shift_is_held :: proc(backend: Engine_Input_Backend) -> bool {
	return(
		engine_input_key_down(backend, .Left_Shift) ||
		engine_input_key_down(backend, .Right_Shift) \
	)
}
