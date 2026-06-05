package renderer

import eng "../engine"

render_world_sprite_or_glyph :: proc(
	engine: ^eng.Engine,
	sprites: ^Sprite_Manager,
	use_sprites: bool,
	sprite: Sprite,
	glyph: rune,
	text: cstring,
	color: eng.Engine_Color,
	x, y, size: i32,
) {
	if use_sprites {
		sprite_manager_draw(engine, sprites, sprite, x, y, color, size)
	} else if text != nil {
		render_draw_text(engine, text, x, y, size, color)
	} else {
		glyph_buf: [2]u8
		glyph_buf[0] = u8(glyph)
		glyph_buf[1] = 0
		render_draw_text(engine, cast(cstring)&glyph_buf[0], x, y, size, color)
	}
}
