package engine

Engine_Key :: enum {
	None,
	W,
	S,
	D,
	A,
	Up,
	Down,
	Right,
	Left,
	Period,
	Escape,
	G,
	X,
	I,
	C,
	Slash,
	M,
	F5,
	F9,
	F1,
	F2,
	Enter,
	Space,
	N,
	H,
	Q,
	R,
	E,
	One,
	Two,
	Three,
	Four,
	Five,
	Six,
	Seven,
	Eight,
	Nine,
	Left_Shift,
	Right_Shift,
	Left_Bracket,
	Right_Bracket,
}

Engine_Mouse_Position :: struct {
	x, y: f32,
}

Engine_Input_Backend :: struct {
	ctx:            rawptr,
	key_down:       proc(ctx: rawptr, key: Engine_Key) -> bool,
	key_pressed:    proc(ctx: rawptr, key: Engine_Key) -> bool,
	key_released:   proc(ctx: rawptr, key: Engine_Key) -> bool,
	frame_time:     proc(ctx: rawptr) -> f32,
	mouse_position: proc(ctx: rawptr) -> Engine_Mouse_Position,
}

engine_input_backend_is_valid :: proc(input: Engine_Input_Backend) -> bool {
	return(
		input.key_down != nil &&
		input.key_pressed != nil &&
		input.key_released != nil &&
		input.frame_time != nil \
	)
}

engine_input_backend_or_default :: proc(input: Engine_Input_Backend) -> Engine_Input_Backend {
	if engine_input_backend_is_valid(input) {
		return input
	}
	return engine_input_backend_default()
}

// Raylib on desktop (input_backend_raylib.odin); nil on JS, where Raylib cannot
// link and the game injects the karl2d input backend.
engine_input_backend_default :: proc() -> Engine_Input_Backend {
	when ODIN_OS == .JS {
		return engine_input_backend_nil()
	} else {
		return engine_input_backend_raylib()
	}
}

engine_input_backend_nil :: proc() -> Engine_Input_Backend {
	return Engine_Input_Backend {
		key_down = nil_input_key_down,
		key_pressed = nil_input_key_pressed,
		key_released = nil_input_key_released,
		frame_time = nil_input_frame_time,
		mouse_position = nil_input_mouse_position,
	}
}

engine_input_key_down :: proc(input: Engine_Input_Backend, key: Engine_Key) -> bool {
	if key == .None {
		return false
	}
	backend := engine_input_backend_or_default(input)
	return backend.key_down(backend.ctx, key)
}

engine_input_key_pressed :: proc(input: Engine_Input_Backend, key: Engine_Key) -> bool {
	if key == .None {
		return false
	}
	backend := engine_input_backend_or_default(input)
	return backend.key_pressed(backend.ctx, key)
}

engine_input_key_released :: proc(input: Engine_Input_Backend, key: Engine_Key) -> bool {
	if key == .None {
		return false
	}
	backend := engine_input_backend_or_default(input)
	return backend.key_released(backend.ctx, key)
}

engine_input_frame_time :: proc(input: Engine_Input_Backend) -> f32 {
	backend := engine_input_backend_or_default(input)
	return backend.frame_time(backend.ctx)
}

engine_input_mouse_position :: proc(input: Engine_Input_Backend) -> Engine_Mouse_Position {
	backend := engine_input_backend_or_default(input)
	if backend.mouse_position == nil {
		return Engine_Mouse_Position{}
	}
	return backend.mouse_position(backend.ctx)
}

engine_mouse_position :: proc(engine: ^Engine) -> Engine_Mouse_Position {
	return engine_input_mouse_position(engine_input_backend(engine))
}

@(private = "file")
nil_input_key_down :: proc(ctx: rawptr, key: Engine_Key) -> bool {
	return false
}

@(private = "file")
nil_input_key_pressed :: proc(ctx: rawptr, key: Engine_Key) -> bool {
	return false
}

@(private = "file")
nil_input_key_released :: proc(ctx: rawptr, key: Engine_Key) -> bool {
	return false
}

@(private = "file")
nil_input_frame_time :: proc(ctx: rawptr) -> f32 {
	return 0
}

@(private = "file")
nil_input_mouse_position :: proc(ctx: rawptr) -> Engine_Mouse_Position {
	return Engine_Mouse_Position{}
}
