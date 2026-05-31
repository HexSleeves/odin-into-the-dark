package main

import rl "vendor:raylib"

// ─── Tile color constants ─────────────────────────────────────────────────────

WALL_COLOR    :: rl.Color{40, 40, 45, 255}
FLOOR_COLOR   :: rl.Color{139, 90, 43, 255}
RUBBLE_COLOR  :: rl.Color{180, 160, 100, 255}
DESCENT_COLOR :: rl.Color{0, 200, 200, 255}
UNSEEN_COLOR  :: rl.Color{0, 0, 0, 255}

// Dimming multiplier for explored-but-not-visible tiles (used in S03 FOV)
EXPLORED_DIM  :: 0.4

// ─── Tile color lookup ────────────────────────────────────────────────────────

get_tile_color :: proc(tile: Tile) -> rl.Color {
	// Pre-FOV: all tiles render as fully visible
	#partial switch tile.type {
	case .Wall:
		return WALL_COLOR
	case .Floor:
		return FLOOR_COLOR
	case .Rubble:
		return RUBBLE_COLOR
	case .Descent:
		return DESCENT_COLOR
	}
	return UNSEEN_COLOR
}

// ─── Map rendering ────────────────────────────────────────────────────────────

render_map :: proc(game: ^Game) {
	for y in 0 ..< MAP_HEIGHT {
		for x in 0 ..< MAP_WIDTH {
			tile := game.tiles[pos_to_idx(x, y)]
			color := get_tile_color(tile)
			rl.DrawRectangle(
				i32(x * TILE_SIZE),
				i32(y * TILE_SIZE),
				i32(TILE_SIZE),
				i32(TILE_SIZE),
				color,
			)
		}
	}
}

// ─── Player rendering ─────────────────────────────────────────────────────────

render_player :: proc(game: ^Game) {
	px := i32(game.player.pos.x * TILE_SIZE)
	py := i32(game.player.pos.y * TILE_SIZE)

	// Draw '@' glyph centered in the tile
	font_size :: i32(TILE_SIZE)
	glyph_buf: [2]u8
	glyph_buf[0] = u8(game.player.glyph)
	glyph_buf[1] = 0
	glyph_cstr := cast(cstring)&glyph_buf[0]
	rl.DrawText(glyph_cstr, px, py, font_size, game.player.color)
}

// ─── Top-level render call ────────────────────────────────────────────────────

render_game :: proc(game: ^Game) {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	render_map(game)
	render_player(game)
	rl.EndDrawing()
}
