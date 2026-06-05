package renderer

import gcore "../core"

import eng "../engine"

// Title backdrop effects are intentionally rendered before Clay UI so they can
// remain lightweight world-style effects while Clay owns layout.
draw_centered_text :: proc(
	engine: ^eng.Engine,
	text: cstring,
	y, size: i32,
	color: eng.Engine_Color,
) {
	text_w := render_measure_text(engine, text, size)
	x := (i32(gcore.SCREEN_WIDTH) - text_w) / 2
	render_draw_text(engine, text, x, y, size, color)
}

draw_title_embers :: proc(engine: ^eng.Engine, frame: int) {
	for i in 0 ..< 18 {
		phase := (frame + i * 37) % 180
		x := i32(120 + (i * 71) % (gcore.SCREEN_WIDTH - 240))
		y := i32(90 + phase * 2)
		if y > 500 {y -= 360}
		alpha := u8(max(25, 140 - phase / 2))
		size := i32(2 + (i % 3))
		render_draw_rectangle(engine, x, y, size, size, eng.Engine_Color{255, 180, 70, alpha})
	}
}
