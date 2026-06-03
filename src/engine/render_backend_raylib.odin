#+build !js
package engine

import rl "vendor:raylib"

// Raylib render backend — desktop default. Excluded from the JS/WASM build,
// which cannot link libraylib.a; web uses the karl2d render backend instead.

engine_render_backend_raylib :: proc() -> Engine_Render_Backend {
	return Engine_Render_Backend {
		begin_frame = raylib_render_begin_frame,
		end_frame = raylib_render_end_frame,
		clear = raylib_render_clear,
		begin_scissor = raylib_render_begin_scissor,
		end_scissor = raylib_render_end_scissor,
		draw_rectangle = raylib_render_draw_rectangle,
		draw_text = raylib_render_draw_text,
		measure_text = raylib_render_measure_text,
		draw_rectangle_lines = raylib_render_draw_rectangle_lines,
		draw_texture_region = raylib_render_draw_texture_region,
	}
}

@(private = "file")
raylib_render_begin_frame :: proc(ctx: rawptr) {
	rl.BeginDrawing()
}

@(private = "file")
raylib_render_end_frame :: proc(ctx: rawptr) {
	rl.EndDrawing()
}

@(private = "file")
raylib_render_clear :: proc(ctx: rawptr, color: Engine_Color) {
	rl.ClearBackground(engine_color_to_raylib(color))
}

@(private = "file")
raylib_render_begin_scissor :: proc(ctx: rawptr, x, y, width, height: i32) {
	rl.BeginScissorMode(x, y, width, height)
}

@(private = "file")
raylib_render_end_scissor :: proc(ctx: rawptr) {
	rl.EndScissorMode()
}

@(private = "file")
raylib_render_draw_rectangle :: proc(ctx: rawptr, x, y, width, height: i32, color: Engine_Color) {
	rl.DrawRectangle(x, y, width, height, engine_color_to_raylib(color))
}

@(private = "file")
raylib_render_draw_rectangle_lines :: proc(
	ctx: rawptr,
	x, y, width, height: i32,
	color: Engine_Color,
) {
	rl.DrawRectangleLines(x, y, width, height, engine_color_to_raylib(color))
}

@(private = "file")
raylib_render_draw_text :: proc(ctx: rawptr, text: cstring, x, y, size: i32, color: Engine_Color) {
	rl.DrawText(text, x, y, size, engine_color_to_raylib(color))
}

@(private = "file")
raylib_render_measure_text :: proc(ctx: rawptr, text: cstring, size: i32) -> i32 {
	return rl.MeasureText(text, size)
}

@(private = "file")
raylib_render_draw_texture_region :: proc(
	ctx: rawptr,
	texture: Engine_Texture,
	source, dest: Engine_Rect,
	origin: Engine_Vec2,
	rotation: f32,
	tint: Engine_Color,
) {
	if texture.handle == nil {
		return
	}
	rl.DrawTexturePro(
		(cast(^rl.Texture2D)texture.handle)^,
		engine_rect_to_raylib(source),
		engine_rect_to_raylib(dest),
		engine_vec2_to_raylib(origin),
		rotation,
		engine_color_to_raylib(tint),
	)
}

@(private = "file")
engine_color_to_raylib :: proc(color: Engine_Color) -> rl.Color {
	return rl.Color{color.r, color.g, color.b, color.a}
}

@(private = "file")
engine_rect_to_raylib :: proc(rect: Engine_Rect) -> rl.Rectangle {
	return rl.Rectangle{x = rect.x, y = rect.y, width = rect.width, height = rect.height}
}

@(private = "file")
engine_vec2_to_raylib :: proc(vec: Engine_Vec2) -> rl.Vector2 {
	return rl.Vector2{vec.x, vec.y}
}
