#+build js
package main

// karl2d backend implementation for web builds.
//
// On WASM, the game uses karl2d's native WebGL backend instead of Raylib+emscripten.
// This file provides the four backend constructors (platform/render/input/texture)
// that slot into game_engine_config via `when ODIN_OS == .JS`.
//
// Audio is NOT covered — karl2d's mixer has no streaming equivalent for music.
// The web build uses nil audio until a web-audio backend is implemented.

import k2 "../../karl2d"
import eng "./engine"
import "core:math"

// ── Value conversions ─────────────────────────────────────────────────────────

@(private = "file")
to_k2_color :: proc(c: eng.Engine_Color) -> k2.Color {
	return k2.Color{c.r, c.g, c.b, c.a}
}

@(private = "file")
to_k2_rect :: proc(r: eng.Engine_Rect) -> k2.Rect {
	return k2.Rect{r.x, r.y, r.width, r.height}
}

@(private = "file")
to_k2_rect_i :: proc(x, y, w, h: i32) -> k2.Rect {
	return k2.Rect{f32(x), f32(y), f32(w), f32(h)}
}

@(private = "file")
to_k2_vec2 :: proc(v: eng.Engine_Vec2) -> k2.Vec2 {
	return k2.Vec2{v.x, v.y}
}

// ── Platform backend ──────────────────────────────────────────────────────────

karl2d_platform_backend :: proc() -> eng.Engine_Platform_Backend {
	return eng.Engine_Platform_Backend {
		init = proc(ctx: rawptr, config: eng.Engine_Config) -> bool {
			k2.init(
				int(config.window_width),
				int(config.window_height),
				string(config.window_title),
			)
			return true
		},
		shutdown = proc(ctx: rawptr) {
			k2.shutdown()
		},
		set_target_fps = proc(ctx: rawptr, target_fps: i32) {},
		disable_exit_key = proc(ctx: rawptr) {},
		window_should_close = proc(ctx: rawptr) -> bool {
			return k2.close_window_requested()
		},
	}
}

// ── Render backend ────────────────────────────────────────────────────────────

karl2d_render_backend :: proc() -> eng.Engine_Render_Backend {
	return eng.Engine_Render_Backend {
		begin_frame = proc(ctx: rawptr) {
			k2.reset_frame_allocator()
			k2.calculate_frame_time()
			k2.process_events()
		},
		end_frame = proc(ctx: rawptr) {
			k2.present()
		},
		clear = proc(ctx: rawptr, color: eng.Engine_Color) {
			k2.clear(to_k2_color(color))
		},
		begin_scissor = proc(ctx: rawptr, x, y, width, height: i32) {
			k2.set_scissor_rect(to_k2_rect_i(x, y, width, height))
		},
		end_scissor = proc(ctx: rawptr) {
			k2.set_scissor_rect(nil)
		},
		draw_rectangle = proc(ctx: rawptr, x, y, width, height: i32, color: eng.Engine_Color) {
			k2.draw_rect(to_k2_rect_i(x, y, width, height), to_k2_color(color))
		},
		draw_rectangle_lines = proc(
			ctx: rawptr,
			x, y, width, height: i32,
			color: eng.Engine_Color,
		) {
			k2.draw_rect_outline(to_k2_rect_i(x, y, width, height), 1, to_k2_color(color))
		},
		draw_text = proc(ctx: rawptr, text: cstring, x, y, size: i32, color: eng.Engine_Color) {
			k2.draw_text(string(text), k2.Vec2{f32(x), f32(y)}, f32(size), to_k2_color(color))
		},
		measure_text = proc(ctx: rawptr, text: cstring, size: i32) -> i32 {
			return i32(k2.measure_text(string(text), f32(size)).x)
		},
		draw_texture_region = proc(
			ctx: rawptr,
			texture: eng.Engine_Texture,
			source, dest: eng.Engine_Rect,
			origin: eng.Engine_Vec2,
			rotation: f32,
			tint: eng.Engine_Color,
		) {
			if texture.handle == nil {return}
			tex := (cast(^k2.Texture)texture.handle)^
			// Engine passes degrees (Raylib convention); karl2d takes radians.
			rad := rotation * (math.PI / 180.0)
			k2.draw_texture_fit(
				tex,
				to_k2_rect(source),
				to_k2_rect(dest),
				to_k2_vec2(origin),
				rad,
				to_k2_color(tint),
			)
		},
	}
}

// ── Input backend ─────────────────────────────────────────────────────────────

karl2d_input_backend :: proc() -> eng.Engine_Input_Backend {
	return eng.Engine_Input_Backend{key_down = proc(ctx: rawptr, key: eng.Engine_Key) -> bool {
			return k2.key_is_held(to_k2_key(key))
		}, key_pressed = proc(ctx: rawptr, key: eng.Engine_Key) -> bool {
			return k2.key_went_down(to_k2_key(key))
		}, key_released = proc(ctx: rawptr, key: eng.Engine_Key) -> bool {
			return k2.key_went_up(to_k2_key(key))
		}, frame_time = proc(ctx: rawptr) -> f32 {
			return k2.get_frame_time()
		}, mouse_position = proc(ctx: rawptr) -> eng.Engine_Mouse_Position {
			p := k2.get_mouse_position()
			return eng.Engine_Mouse_Position{x = p.x, y = p.y}
		}}
}

// ── Texture backend (web: bytes-based) ────────────────────────────────────────

karl2d_texture_backend :: proc() -> eng.Engine_Texture_Backend {
	return eng.Engine_Texture_Backend {
		load = proc(ctx: rawptr, path: string) -> eng.Engine_Texture {
			// On web, path-based loading uses the compile-time embedded asset registry.
			data, ok := web_asset_lookup(path)
			if !ok {return {}}
			tex := new(k2.Texture)
			tex^ = k2.load_texture_from_bytes(data)
			if tex.width == 0 {
				free(tex)
				return {}
			}
			return eng.Engine_Texture {
				handle = rawptr(tex),
				width = i32(tex.width),
				height = i32(tex.height),
			}
		},
		unload = proc(ctx: rawptr, texture: ^eng.Engine_Texture) {
			if texture == nil || texture.handle == nil {return}
			tex := cast(^k2.Texture)texture.handle
			k2.destroy_texture(tex^)
			free(tex)
			texture^ = {}
		},
	}
}

// ── Key mapping ───────────────────────────────────────────────────────────────

@(private = "file")
to_k2_key :: proc(key: eng.Engine_Key) -> k2.Keyboard_Key {
	switch key {
	case .None:
		return .None
	case .W:
		return .W
	case .S:
		return .S
	case .D:
		return .D
	case .A:
		return .A
	case .Up:
		return .Up
	case .Down:
		return .Down
	case .Right:
		return .Right
	case .Left:
		return .Left
	case .Period:
		return .Period
	case .Escape:
		return .Escape
	case .G:
		return .G
	case .X:
		return .X
	case .I:
		return .I
	case .C:
		return .C
	case .Slash:
		return .Slash
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
		return .Enter
	case .Space:
		return .Space
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
		return .N1
	case .Two:
		return .N2
	case .Three:
		return .N3
	case .Four:
		return .N4
	case .Five:
		return .N5
	case .Six:
		return .N6
	case .Seven:
		return .N7
	case .Eight:
		return .N8
	case .Nine:
		return .N9
	case .Left_Shift:
		return .Left_Shift
	case .Right_Shift:
		return .Right_Shift
	case .Left_Bracket:
		return .Left_Bracket
	case .Right_Bracket:
		return .Right_Bracket
	case:
		return .None
	}
}
