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

// ─── Tile color helpers ───────────────────────────────────────────────────────

dim_color :: proc(c: rl.Color, factor: f32) -> rl.Color {
	return rl.Color{
		u8(f32(c.r) * factor),
		u8(f32(c.g) * factor),
		u8(f32(c.b) * factor),
		c.a,
	}
}

base_tile_color :: proc(type: Tile_Type) -> rl.Color {
	#partial switch type {
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

get_tile_color :: proc(tile: Tile) -> rl.Color {
	if tile.visible {
		// Visible: full color modulated by light_level for falloff
		return dim_color(base_tile_color(tile.type), max(tile.light_level, 0.3))
	}
	if tile.explored {
		// Explored but not visible: dimmed
		return dim_color(base_tile_color(tile.type), EXPLORED_DIM)
	}
	// Unseen
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

// ─── Enemy rendering ──────────────────────────────────────────────────────────

render_enemies :: proc(game: ^Game) {
	for &enemy in game.enemies {
		if !enemy.alive { continue }

		// Only render enemies on visible tiles
		tile := tile_at(game, enemy.pos.x, enemy.pos.y)
		if tile == nil || !tile.visible { continue }

		ex := i32(enemy.pos.x * TILE_SIZE)
		ey := i32(enemy.pos.y * TILE_SIZE)

		font_size :: i32(TILE_SIZE)
		glyph_buf: [2]u8
		glyph_buf[0] = u8(enemy.glyph)
		glyph_buf[1] = 0
		glyph_cstr := cast(cstring)&glyph_buf[0]
		rl.DrawText(glyph_cstr, ex, ey, font_size, enemy.color)
	}
}

// ─── HUD rendering ────────────────────────────────────────────────────────────

HUD_Y      :: i32(MAP_HEIGHT * TILE_SIZE + 4)
HUD_HEIGHT :: i32(SCREEN_HEIGHT) - HUD_Y

render_hud :: proc(game: ^Game) {
	// Background bar
	rl.DrawRectangle(0, HUD_Y, i32(SCREEN_WIDTH), HUD_HEIGHT, rl.Color{20, 20, 25, 255})

	// HP bar
	hp_ratio := f32(max(game.player.hp, 0)) / f32(game.player.max_hp)
	hp_bar_w :: i32(200)
	hp_bar_h :: i32(16)
	hp_x :: i32(8)
	hp_y := HUD_Y + 4

	// Background (red)
	rl.DrawRectangle(hp_x, hp_y, hp_bar_w, hp_bar_h, rl.Color{80, 20, 20, 255})
	// Foreground (green)
	rl.DrawRectangle(hp_x, hp_y, i32(f32(hp_bar_w) * hp_ratio), hp_bar_h, rl.Color{40, 180, 40, 255})

	// HP text
	rl.DrawText(rl.TextFormat("HP: %d/%d", i32(game.player.hp), i32(game.player.max_hp)),
		hp_x + 4, hp_y + 1, 14, rl.WHITE)

	// Stats line
	stats_y := hp_y + hp_bar_h + 4

	// Count alive enemies
	alive_count: i32 = 0
	for &e in game.enemies {
		if e.alive { alive_count += 1 }
	}

	rl.DrawText(rl.TextFormat("Depth: %d  |  Light: %d  |  Enemies: %d  |  Turn: %d",
		i32(game.depth), i32(game.player.light_radius), alive_count, i32(game.turn_count)),
		hp_x, stats_y, 14, rl.Color{180, 180, 180, 255})
}

// ─── Game Over screen ─────────────────────────────────────────────────────────

render_game_over :: proc(game: ^Game) {
	// Dim overlay
	rl.DrawRectangle(0, 0, i32(SCREEN_WIDTH), i32(SCREEN_HEIGHT), rl.Color{0, 0, 0, 180})

	// "GAME OVER" centered
	title_size :: i32(40)
	title := cstring("GAME OVER")
	title_w := rl.MeasureText(title, title_size)
	title_x := (i32(SCREEN_WIDTH) - title_w) / 2
	title_y := i32(SCREEN_HEIGHT) / 2 - 60
	rl.DrawText(title, title_x, title_y, title_size, rl.RED)

	// Depth reached
	depth_size :: i32(20)
	depth_text := rl.TextFormat("Reached depth %d", i32(game.depth))
	depth_w := rl.MeasureText(depth_text, depth_size)
	depth_x := (i32(SCREEN_WIDTH) - depth_w) / 2
	rl.DrawText(depth_text, depth_x, title_y + 50, depth_size, rl.Color{200, 200, 200, 255})

	// Restart prompt
	restart := cstring("Press R to restart  |  ESC to quit")
	restart_size :: i32(16)
	restart_w := rl.MeasureText(restart, restart_size)
	restart_x := (i32(SCREEN_WIDTH) - restart_w) / 2
	rl.DrawText(restart, restart_x, title_y + 80, restart_size, rl.Color{150, 150, 150, 255})
}

// ─── Top-level render call ────────────────────────────────────────────────────

render_game :: proc(game: ^Game) {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	render_map(game)
	render_enemies(game)
	render_player(game)
	render_hud(game)
	if game.state == .Game_Over {
		render_game_over(game)
	}

	rl.EndDrawing()
}
