package core

// Shadowcasting FOV — recursive octant expansion.
// Called by gameplay and io packages; neither can import the other.

@(private = "file")
OCTANT_MULTIPLIERS :: [8][4]int {
	{1, 0, 0, 1},
	{0, 1, 1, 0},
	{0, -1, 1, 0},
	{-1, 0, 0, 1},
	{-1, 0, 0, -1},
	{0, -1, -1, 0},
	{0, 1, -1, 0},
	{1, 0, 0, -1},
}

compute_fov :: proc(game: ^Game) {
	if game == nil {return}
	tile_states_clear_visibility(game)
	px := game.player.pos.x
	py := game.player.pos.y
	radius := game.player.light_radius + game.light_boost_bonus + effective_light_bonus(game)
	_ = tile_state_set(game, px, py, true, true, 1.0)
	mults := OCTANT_MULTIPLIERS
	for oct in 0 ..< 8 {
		fov_cast_light(game, px, py, radius, 1, 1.0, 0.0, mults[oct])
	}
}

@(private = "file")
fov_cast_light :: proc(
	game: ^Game,
	origin_x, origin_y: int,
	radius: int,
	row: int,
	start_slope: f64,
	end_slope: f64,
	mult: [4]int,
) {
	start := start_slope
	if start < end_slope {return}
	radius_sq := f64(radius * radius)
	for j := row; j <= radius; j += 1 {
		dx := -j - 1
		dy := -j
		blocked := false
		next_start := start
		for dx <= 0 {
			dx += 1
			map_x := origin_x + dx * mult[0] + dy * mult[1]
			map_y := origin_y + dx * mult[2] + dy * mult[3]
			l_slope := (f64(dx) - 0.5) / (f64(dy) + 0.5)
			r_slope := (f64(dx) + 0.5) / (f64(dy) - 0.5)
			if start < r_slope {continue}
			if end_slope > l_slope {break}
			dist_sq := f64(dx * dx + dy * dy)
			if dist_sq <= radius_sq && tile_at(game, map_x, map_y) != nil {
				_ = tile_state_set(game, map_x, map_y, true, true, f32(1.0 - dist_sq / radius_sq))
			}
			if blocked {
				if fov_is_opaque(game, map_x, map_y) {
					next_start = r_slope
					continue
				} else {
					blocked = false
					start = next_start
				}
			} else if fov_is_opaque(game, map_x, map_y) && j < radius {
				blocked = true
				fov_cast_light(game, origin_x, origin_y, radius, j + 1, start, l_slope, mult)
				next_start = r_slope
			}
		}
		if blocked {break}
	}
}

@(private = "file")
fov_is_opaque :: proc(game: ^Game, x, y: int) -> bool {
	t := tile_at(game, x, y)
	if t == nil {return true}
	#partial switch t.type {
	case .Wall, .Locked_Door:
		return true
	}
	return false
}
