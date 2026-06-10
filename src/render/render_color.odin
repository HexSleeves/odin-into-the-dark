package renderer

import eng "../engine"

render_draw_rectangle :: proc(
	engine: ^eng.Engine,
	x, y, width, height: i32,
	color: eng.Engine_Color,
) {
	eng.engine_render_draw_rectangle(engine, x, y, width, height, color)
}

render_draw_rectangle_lines :: proc(
	engine: ^eng.Engine,
	x, y, width, height: i32,
	color: eng.Engine_Color,
) {
	eng.engine_render_draw_rectangle_lines(engine, x, y, width, height, color)
}

render_draw_text :: proc(
	engine: ^eng.Engine,
	text: cstring,
	x, y, size: i32,
	color: eng.Engine_Color,
	font := eng.Engine_Font.Body,
) {
	eng.engine_render_draw_text(engine, text, x, y, size, color, font)
}

render_measure_text :: proc(
	engine: ^eng.Engine,
	text: cstring,
	size: i32,
	font := eng.Engine_Font.Body,
) -> i32 {
	return eng.engine_render_measure_text(engine, text, size, font)
}

render_draw_texture_region :: proc(
	engine: ^eng.Engine,
	texture: eng.Engine_Texture,
	source, dest: eng.Engine_Rect,
	origin: eng.Engine_Vec2,
	rotation: f32,
	tint: eng.Engine_Color,
) {
	eng.engine_render_draw_texture_region(engine, texture, source, dest, origin, rotation, tint)
}
