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

		spr := sprite_manager_item(sprites, item.item_type)
		render_world_sprite_or_glyph(engine, sprites, ui.use_sprites, spr, item.glyph, nil, item.color, ix, iy, tile_size)
	}
}

// ─── Spawn items into rooms (data-driven) ─────────────────────────────────────
