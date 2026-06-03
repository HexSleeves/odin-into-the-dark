// SPIKE — karl2d backend implementation for the engine's backend tables.
//
// This is a PROOF-OF-CONCEPT, not production code. It demonstrates that the
// engine's four swappable backend tables (platform / render / input / texture)
// can be satisfied by karl2d (https://github.com/karl-zylinski/karl2d) instead
// of Raylib, with NO changes to the engine package or the game logic.
//
// It lives under spike/ so the default `odin build src/` and `just verify` do
// NOT compile it (karl2d is not linked into the shipped desktop binary yet).
//
// Type-check it in isolation against the real engine + karl2d sources:
//
//   odin check spike/karl2d_backend -no-entry-point
//
// (Run from the repo root. Imports are relative, matching the project's own
// `import eng "./engine"` convention. See spike/karl2d_backend/README.md for the web
// build + game_app.odin wiring story.)
//
// ── Why this matters ──────────────────────────────────────────────────────
// karl2d's headline win for this project is web export with NO emscripten
// (its own WebGL backend). The engine already routes 100% of rendering through
// these tables, so adopting karl2d for the web target is a backend swap, not a
// rewrite. The only game-layer surface that does NOT flow through here is audio
// (audio.odin / music.odin) — music streaming has no karl2d 1:1 equivalent and
// needs a separate design pass. See the audit in the conversation that produced
// this spike.

package karl2d_backend

import k2 "../../../karl2d"
import eng "../../src/engine"

// ── Value conversions ───────────────────────────────────────────────────────
// Engine_Color is {r,g,b,a: u8}; k2.Color is [4]u8 — same bytes, distinct types.

@(private)
to_k2_color :: proc(c: eng.Engine_Color) -> k2.Color {
	return k2.Color{c.r, c.g, c.b, c.a}
}

@(private)
to_k2_rect :: proc(r: eng.Engine_Rect) -> k2.Rect {
	return k2.Rect{r.x, r.y, r.width, r.height}
}

@(private)
to_k2_rect_i :: proc(x, y, w, h: i32) -> k2.Rect {
	return k2.Rect{f32(x), f32(y), f32(w), f32(h)}
}

@(private)
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
		// karl2d has no target-fps knob (it relies on the platform vsync). No-op.
		set_target_fps = proc(ctx: rawptr, target_fps: i32) {},
		// karl2d does not auto-close the window on a "quit key", so there is
		// nothing to disable — close is reported via close_window_requested().
		disable_exit_key = proc(ctx: rawptr) {},
		window_should_close = proc(ctx: rawptr) -> bool {
			return k2.close_window_requested()
		},
	}
}

// ── Render backend ──────────────────────────────────────────────────────────
//
// SEAM NOTE: Raylib splits the frame into BeginDrawing()/EndDrawing(). karl2d's
// k2.update() bundles process_events + calculate_frame_time + reset_frame_alloc.
// The engine loop calls window_should_close() then begin_frame(); to keep frame
// timing and input fresh we run the granular karl2d setup procs in begin_frame.
// This ordering should be validated against engine_run's loop when wired in.

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
			if texture.handle == nil {
				return
			}
			tex := (cast(^k2.Texture)texture.handle)^
			// karl2d rotation is radians; the engine passes degrees (Raylib
			// convention). A real port converts here — left as-is for the spike
			// to keep the mapping 1:1 and obvious.
			k2.draw_texture_fit(
				tex,
				to_k2_rect(source),
				to_k2_rect(dest),
				to_k2_vec2(origin),
				rotation,
				to_k2_color(tint),
			)
		},
	}
}

// ── Input backend ───────────────────────────────────────────────────────────

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

// ── Texture backend ───────────────────────────────────────────────────────────
//
// On web, karl2d cannot read files from disk (file_system_web.odin is a stub);
// assets must be embedded with `#load` or shipped via load_texture_from_bytes.
// This load-from-path path is the DESKTOP story; the web wiring substitutes a
// bytes-based loader. Documented in README.md.

karl2d_texture_backend :: proc() -> eng.Engine_Texture_Backend {
	return eng.Engine_Texture_Backend {
		load = proc(ctx: rawptr, path: string) -> eng.Engine_Texture {
			tex := new(k2.Texture)
			tex^ = k2.load_texture_from_file(path)
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
			if texture == nil || texture.handle == nil {
				return
			}
			tex := cast(^k2.Texture)texture.handle
			k2.destroy_texture(tex^)
			free(tex)
			texture^ = {}
		},
	}
}

// ── Key mapping ───────────────────────────────────────────────────────────────
// Every Engine_Key has a karl2d equivalent. Numbers map Engine .One→k2 .N1, etc.

@(private)
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
	case:
		return .None
	}
}
