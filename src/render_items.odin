package main

import eng "./engine"


render_items :: proc(engine: ^eng.Engine, game: ^Game) {
	sprites := game_engine_sprite_manager(engine)
	camera := game_engine_camera_manager(engine)
	vfx := game_engine_vfx_manager(engine)
	ui := ui_manager_state(game_engine_ui_manager(engine))
	tile_size := camera_tile_size(camera)

	for &item in game.items {
		if item.picked_up {continue}

		// Only render items on visible tiles
		if !tile_visible_at(game, item.pos.x, item.pos.y) {continue}

		ix := camera_world_x_to_screen_shaken(camera, vfx, item.pos.x * TILE_SIZE)
		iy := camera_world_y_to_screen_shaken(camera, vfx, item.pos.y * TILE_SIZE)

		if ui.use_sprites {
			spr := sprite_manager_item(sprites, item.item_type)
			sprite_manager_draw(engine, sprites, spr, ix, iy, item.color, tile_size)
		} else {
			glyph_buf: [2]u8
			glyph_buf[0] = u8(item.glyph)
			glyph_buf[1] = 0
			glyph_cstr := cast(cstring)&glyph_buf[0]
			render_draw_text(engine, glyph_cstr, ix, iy, tile_size, item.color)
		}
	}
}

// ─── Spawn items into rooms (data-driven) ─────────────────────────────────────
