package main

// ─── Map helpers ──────────────────────────────────────────────────────────────

pos_to_idx :: proc(x, y: int) -> int {
	return y * MAP_WIDTH + x
}

idx_to_pos :: proc(idx: int) -> Vec2 {
	return Vec2{idx % MAP_WIDTH, idx / MAP_WIDTH}
}

tile_at :: proc(game: ^Game, x, y: int) -> ^Tile {
	if x < 0 || x >= MAP_WIDTH || y < 0 || y >= MAP_HEIGHT {
		return nil
	}
	return &game.tiles[pos_to_idx(x, y)]
}

is_walkable :: proc(game: ^Game, x, y: int) -> bool {
	t := tile_at(game, x, y)
	if t == nil {
		return false
	}
	#partial switch t.type {
	case .Floor, .Rubble, .Descent, .Water, .Gas_Vent, .Unstable, .Anvil:
		return true
	}
	return false
}
