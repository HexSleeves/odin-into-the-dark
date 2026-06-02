package main

import rl "vendor:raylib"
import eng "./engine"

engine_color_from_rl :: proc(color: rl.Color) -> eng.Engine_Color {
	return eng.engine_color_make(color.r, color.g, color.b, color.a)
}

engine_rect_from_rl :: proc(rect: rl.Rectangle) -> eng.Engine_Rect {
	return eng.engine_rect_make(rect.x, rect.y, rect.width, rect.height)
}

engine_vec2_from_rl :: proc(vec: rl.Vector2) -> eng.Engine_Vec2 {
	return eng.engine_vec2_make(vec.x, vec.y)
}

render_draw_rectangle :: proc(engine: ^eng.Engine, x, y, width, height: i32, color: rl.Color) {
	eng.engine_render_draw_rectangle(engine, x, y, width, height, engine_color_from_rl(color))
}

render_draw_rectangle_lines :: proc(engine: ^eng.Engine, x, y, width, height: i32, color: rl.Color) {
	eng.engine_render_draw_rectangle_lines(engine, x, y, width, height, engine_color_from_rl(color))
}

render_draw_text :: proc(engine: ^eng.Engine, text: cstring, x, y, size: i32, color: rl.Color) {
	eng.engine_render_draw_text(engine, text, x, y, size, engine_color_from_rl(color))
}

render_measure_text :: proc(engine: ^eng.Engine, text: cstring, size: i32) -> i32 {
	return eng.engine_render_measure_text(engine, text, size)
}

render_draw_texture_region :: proc(
	engine: ^eng.Engine,
	texture: eng.Engine_Texture,
	source, dest: rl.Rectangle,
	origin: rl.Vector2,
	rotation: f32,
	tint: rl.Color,
) {
	eng.engine_render_draw_texture_region(
		engine,
		texture,
		engine_rect_from_rl(source),
		engine_rect_from_rl(dest),
		engine_vec2_from_rl(origin),
		rotation,
		engine_color_from_rl(tint),
	)
}
