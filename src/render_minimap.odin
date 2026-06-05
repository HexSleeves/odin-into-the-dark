package main

import eng "./engine"


// ─── Minimap overlay ──────────────────────────────────────────────────────────

MINIMAP_TILE_SIZE :: i32(2) // each map tile = 2x2 pixels on minimap
minimap_should_draw_enemy_dot :: proc(game: ^Game, enemy: ^Enemy) -> bool {
	if game == nil || enemy == nil || !enemy.alive {
		return false
	}
	if tile_visible_at(game, enemy.pos.x, enemy.pos.y) {
		return true
	}
	return game.minimap_reveal_enemies && tile_explored_at(game, enemy.pos.x, enemy.pos.y)
}

MINIMAP_MARGIN :: i32(8)

when !USE_CLAY {
	render_minimap :: proc(engine: ^eng.Engine, game: ^Game) {
		mm_w := i32(MAP_WIDTH) * MINIMAP_TILE_SIZE
		mm_h := i32(MAP_HEIGHT) * MINIMAP_TILE_SIZE
		mm_x := i32(MAP_VIEW_WIDTH) - mm_w - MINIMAP_MARGIN
		mm_y := MINIMAP_MARGIN

		render_draw_rectangle(
			engine,
			mm_x - 2,
			mm_y - 2,
			mm_w + 4,
			mm_h + 4,
			eng.Engine_Color{0, 0, 0, 180},
		)

		for y in 0 ..< MAP_HEIGHT {
			for x in 0 ..< MAP_WIDTH {
				idx := pos_to_idx(x, y)
				tile := game.tiles[idx]
				state := tile_state_at_idx(game, idx)

				px := mm_x + i32(x) * MINIMAP_TILE_SIZE
				py := mm_y + i32(y) * MINIMAP_TILE_SIZE

				if state.visible {
					c: eng.Engine_Color
					#partial switch tile.type {
					case .Wall:
						c = eng.Engine_Color{80, 80, 90, 255}
					case .Floor:
						c = eng.Engine_Color{160, 120, 60, 255}
					case .Rubble:
						c = eng.Engine_Color{140, 130, 90, 255}
					case .Descent:
						c = eng.Engine_Color{0, 255, 255, 255}
					case:
						c = eng.Engine_Color{120, 100, 80, 255}
					}
					render_draw_rectangle(engine, px, py, MINIMAP_TILE_SIZE, MINIMAP_TILE_SIZE, c)
				} else if state.explored {
					c: eng.Engine_Color
					#partial switch tile.type {
					case .Wall:
						c = eng.Engine_Color{30, 30, 35, 255}
					case .Floor:
						c = eng.Engine_Color{60, 45, 25, 255}
					case .Rubble:
						c = eng.Engine_Color{55, 50, 35, 255}
					case .Descent:
						c = eng.Engine_Color{0, 80, 80, 255}
					case:
						c = eng.Engine_Color{50, 40, 30, 255}
					}
					render_draw_rectangle(engine, px, py, MINIMAP_TILE_SIZE, MINIMAP_TILE_SIZE, c)
				}
			}
		}

		for &enemy in game.enemies {
			if !minimap_should_draw_enemy_dot(game, &enemy) {continue}
			ex := mm_x + i32(enemy.pos.x) * MINIMAP_TILE_SIZE
			ey := mm_y + i32(enemy.pos.y) * MINIMAP_TILE_SIZE
			render_draw_rectangle(
				engine,
				ex,
				ey,
				MINIMAP_TILE_SIZE,
				MINIMAP_TILE_SIZE,
				eng.Engine_Color{255, 60, 60, 255},
			)
		}

		player_px := mm_x + i32(game.player.pos.x) * MINIMAP_TILE_SIZE
		player_py := mm_y + i32(game.player.pos.y) * MINIMAP_TILE_SIZE
		render_draw_rectangle(
			engine,
			player_px,
			player_py,
			MINIMAP_TILE_SIZE,
			MINIMAP_TILE_SIZE,
			eng.Engine_Color{255, 255, 0, 255},
		)
	}
}

when USE_CLAY {
	render_minimap :: proc(engine: ^eng.Engine, game: ^Game) {
		_ = engine
		clay_render_minimap(game)
	}
}
