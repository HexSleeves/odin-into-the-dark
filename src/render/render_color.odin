package renderer

import eng "../engine"

render_draw_rectangle :: proc(
	engine: ^eng.Engine,
	x, y, width, height: i32,
	color: eng.Engine_Color,
) {
	eng.engine_render_draw_rectangle(engine, x, y, width, height, color)
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
