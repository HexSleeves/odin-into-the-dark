#+build !js
package engine

import rl "vendor:raylib"

// Raylib input backend — desktop default. Excluded from the JS/WASM build,
// which cannot link libraylib.a; web uses the karl2d input backend instead.

engine_input_backend_raylib :: proc() -> Engine_Input_Backend {
	return Engine_Input_Backend {
		key_down = raylib_input_key_down,
		key_pressed = raylib_input_key_pressed,
		key_released = raylib_input_key_released,
		frame_time = raylib_input_frame_time,
		mouse_position = raylib_input_mouse_position,
		mouse_button_down = raylib_input_mouse_button_down,
		mouse_button_released = raylib_input_mouse_button_released,
		scroll_delta = raylib_input_scroll_delta,
	}
}

@(private = "file")
raylib_input_key_down :: proc(ctx: rawptr, key: Engine_Key) -> bool {
	return rl.IsKeyDown(engine_key_to_raylib(key))
}

@(private = "file")
raylib_input_key_pressed :: proc(ctx: rawptr, key: Engine_Key) -> bool {
	return rl.IsKeyPressed(engine_key_to_raylib(key))
}

@(private = "file")
raylib_input_key_released :: proc(ctx: rawptr, key: Engine_Key) -> bool {
	return rl.IsKeyReleased(engine_key_to_raylib(key))
}

@(private = "file")
raylib_input_frame_time :: proc(ctx: rawptr) -> f32 {
	return rl.GetFrameTime()
}

@(private = "file")
raylib_input_mouse_position :: proc(ctx: rawptr) -> Engine_Mouse_Position {
	mouse := rl.GetMousePosition()
	return Engine_Mouse_Position{x = mouse.x, y = mouse.y}
}

@(private = "file")
raylib_input_mouse_button_down :: proc(ctx: rawptr, button: Engine_Mouse_Button) -> bool {
	return rl.IsMouseButtonDown(engine_mouse_button_to_raylib(button))
}

@(private = "file")
raylib_input_mouse_button_released :: proc(ctx: rawptr, button: Engine_Mouse_Button) -> bool {
	return rl.IsMouseButtonReleased(engine_mouse_button_to_raylib(button))
}

@(private = "file")
raylib_input_scroll_delta :: proc(ctx: rawptr) -> f32 {
	return rl.GetMouseWheelMove()
}

@(private = "file")
engine_mouse_button_to_raylib :: proc(button: Engine_Mouse_Button) -> rl.MouseButton {
	#partial switch button {
	case .Left:
		return .LEFT
	case .Right:
		return .RIGHT
	case .Middle:
		return .MIDDLE
	}
	return .LEFT
}

engine_key_to_raylib :: proc(key: Engine_Key) -> rl.KeyboardKey {
	#partial switch key {
	case .W:
		return .W
	case .S:
		return .S
	case .D:
		return .D
	case .A:
		return .A
	case .Up:
		return .UP
	case .Down:
		return .DOWN
	case .Right:
		return .RIGHT
	case .Left:
		return .LEFT
	case .Period:
		return .PERIOD
	case .Escape:
		return .ESCAPE
	case .G:
		return .G
	case .X:
		return .X
	case .I:
		return .I
	case .C:
		return .C
	case .Slash:
		return .SLASH
	case .M:
		return .M
	case .F5:
		return .F5
	case .F9:
		return .F9
	case .F1:
		return .F1
	case .F2:
		return .F2
	case .Enter:
		return .ENTER
	case .Space:
		return .SPACE
	case .N:
		return .N
	case .H:
		return .H
	case .Q:
		return .Q
	case .R:
		return .R
	case .E:
		return .E
	case .One:
		return .ONE
	case .Two:
		return .TWO
	case .Three:
		return .THREE
	case .Four:
		return .FOUR
	case .Five:
		return .FIVE
	case .Six:
		return .SIX
	case .Seven:
		return .SEVEN
	case .Eight:
		return .EIGHT
	case .Nine:
		return .NINE
	case .Left_Shift:
		return .LEFT_SHIFT
	case .Right_Shift:
		return .RIGHT_SHIFT
	case .Left_Bracket:
		return .LEFT_BRACKET
	case .Right_Bracket:
		return .RIGHT_BRACKET
	case:
		return .KEY_NULL
	}
}
