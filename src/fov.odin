package main

import "core:log"

// ─── FOV computation (recursive shadowcasting) ───────────────────────────────
//
// Uses octant-based recursive shadowcasting for symmetric, wall-aware FOV.
// Reference: http://www.roguebasin.com/index.php/FOV_using_recursive_shadowcasting

// Octant multipliers: each octant transforms (row, col) into (dx, dy)
@(private = "file")
OCTANT_MULTIPLIERS :: [8][4]int {
	{1, 0, 0, 1}, // octant 0
	{0, 1, 1, 0}, // octant 1
	{0, -1, 1, 0}, // octant 2
	{-1, 0, 0, 1}, // octant 3
	{-1, 0, 0, -1}, // octant 4
	{0, -1, -1, 0}, // octant 5
	{0, 1, -1, 0}, // octant 6
	{1, 0, 0, -1}, // octant 7
}

// ─── Public entry point ──────────────────────────────────────────────────────

compute_fov :: proc(game: ^Game) {
	// Clear visibility for all tiles
	for &tile in game.tiles {
		tile.visible = false
		tile.light_level = 0
	}

	// Player's tile is always visible
	px := game.player.pos.x
	py := game.player.pos.y
	radius := game.player.light_radius + game.light_boost_bonus + effective_light_bonus(game)

	player_tile := tile_at(game, px, py)
	if player_tile != nil {
		player_tile.visible = true
		player_tile.explored = true
		player_tile.light_level = 1.0
	}

	// Cast light in all 8 octants
	mults := OCTANT_MULTIPLIERS
	for oct in 0 ..< 8 {
		cast_light(game, px, py, radius, 1, 1.0, 0.0, mults[oct])
	}

	// Diagnostic: count visible tiles
	if logger_should_log(&g_logger, log.Level.Debug, .Fov) {
		visible_count := 0
		for &tile in game.tiles {
			if tile.visible {
				visible_count += 1
			}
		}
		logger_debugf(.Fov, "recomputed: %v tiles visible (radius=%v)", visible_count, radius)
	}
}

// ─── Recursive shadowcasting for one octant ──────────────────────────────────

@(private = "file")
cast_light :: proc(
	game: ^Game,
	origin_x, origin_y: int,
	radius: int,
	row: int,
	start_slope: f64,
	end_slope: f64,
	mult: [4]int,
) {
	start := start_slope

	if start < end_slope {
		return
	}

	radius_sq := f64(radius * radius)

	for j := row; j <= radius; j += 1 {
		dx := -j - 1
		dy := -j

		blocked := false
		next_start := start

		for dx <= 0 {
			dx += 1

			// Map coordinates via octant transform
			map_x := origin_x + dx * mult[0] + dy * mult[1]
			map_y := origin_y + dx * mult[2] + dy * mult[3]

			// Slopes for this cell
			l_slope := (f64(dx) - 0.5) / (f64(dy) + 0.5)
			r_slope := (f64(dx) + 0.5) / (f64(dy) - 0.5)

			if start < r_slope {
				continue
			}
			if end_slope > l_slope {
				break
			}

			// Distance check (circular FOV)
			dist_sq := f64(dx * dx + dy * dy)
			if dist_sq <= radius_sq {
				t := tile_at(game, map_x, map_y)
				if t != nil {
					t.visible = true
					t.explored = true
					// Light falls off with distance
					t.light_level = f32(1.0 - dist_sq / radius_sq)
				}
			}

			if blocked {
				// Previous cell was a wall
				if is_opaque(game, map_x, map_y) {
					next_start = r_slope
					continue
				} else {
					blocked = false
					start = next_start
				}
			} else {
				if is_opaque(game, map_x, map_y) && j < radius {
					// Start a new scan skipping this wall
					blocked = true
					cast_light(game, origin_x, origin_y, radius, j + 1, start, l_slope, mult)
					next_start = r_slope
				}
			}
		}

		if blocked {
			break
		}
	}
}

// ─── Opacity check ───────────────────────────────────────────────────────────

@(private = "file")
is_opaque :: proc(game: ^Game, x, y: int) -> bool {
	t := tile_at(game, x, y)
	if t == nil {
		return true // out-of-bounds blocks LOS
	}
	return t.type == .Wall || t.type == .Chasm
}
