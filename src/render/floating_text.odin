package renderer

import gcore "../core"

import eng "../engine"

FLOATING_TEXT_SIZE :: 12

// render_floating_text draws all active floating-text entries in world space,
// converting tile coords to screen pixels via the camera and applying each
// entry's rise offset and life-based alpha fade. Call inside the map scissor.
render_floating_text :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	ft := game_engine_floating_text_manager(engine)
	if ft == nil {return}
	camera := game_engine_camera_manager(engine)
	vfx := game_engine_vfx_manager(engine)

	for &entry in ft.pool {
		if !entry.active {continue}

		// Center horizontally on the tile; rise upward as the entry ages.
		world_x := entry.tile_x * gcore.TILE_SIZE + gcore.TILE_SIZE / 2
		rise_px := int(entry.rise * f32(gcore.TILE_SIZE))
		world_y := entry.tile_y * gcore.TILE_SIZE - rise_px

		sx := camera_world_x_to_screen_shaken(camera, vfx, world_x)
		sy := camera_world_y_to_screen_shaken(camera, vfx, world_y)

		alpha := u8(clamp(entry.life, 0, 1) * f32(entry.color.a))
		color := eng.Engine_Color{entry.color.r, entry.color.g, entry.color.b, alpha}

		text := eng.floating_text_text(&entry)
		buf: [eng.ENGINE_FLOATING_TEXT_MAX_LEN + 1]u8
		n := min(len(text), eng.ENGINE_FLOATING_TEXT_MAX_LEN)
		for i in 0 ..< n {buf[i] = text[i]}
		buf[n] = 0
		render_draw_text(engine, cstring(&buf[0]), sx, sy, FLOATING_TEXT_SIZE, color)
	}
}
