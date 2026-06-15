package gen

import "core:math/rand"


spawn_ore_veins :: proc(game: ^Game) {
	// Clear ore veins
	for i in 0 ..< MAP_WIDTH * MAP_HEIGHT {
		game.ore_veins[i] = {}
	}

	depth := game.depth

	// Scan all wall tiles, ~10% chance to become ore vein
	for y in 1 ..< MAP_HEIGHT - 1 {
		for x in 1 ..< MAP_WIDTH - 1 {
			idx := pos_to_idx(x, y)
			if game.tiles[idx].type != .Wall {continue}

			// ~10% chance for wall to be ore
			if rand.int_max(100) >= 10 {continue}

			// Check if wall is adjacent to at least one floor-like tile (accessible)
			has_floor := false
			adj_dx := CARDINAL_DX
			adj_dy := CARDINAL_DY
			for dir in 0 ..< 4 {
				nx := x + adj_dx[dir]
				ny := y + adj_dy[dir]
				if nx >= 0 && nx < MAP_WIDTH && ny >= 0 && ny < MAP_HEIGHT {
					t := game.tiles[pos_to_idx(nx, ny)]
					if t.type == .Floor ||
					   t.type == .Rubble ||
					   t.type == .Descent ||
					   t.type == .Water ||
					   t.type == .Gas_Vent ||
					   t.type == .Unstable {
						has_floor = true
						break
					}
				}
			}
			if !has_floor {continue}

			// Weighted ore type selection by depth
			kind: Ore_Kind
			roll := rand.int_max(100)

			if depth >= 8 {
				// iron 10, copper 25, crystal 35, gold 30
				if roll <
				   10 {kind = .Iron} else if roll < 35 {kind = .Copper} else if roll < 70 {kind = .Crystal} else {kind = .Gold}
			} else if depth >= 5 {
				// iron 20, copper 40, crystal 40
				if roll <
				   20 {kind = .Iron} else if roll < 60 {kind = .Copper} else {kind = .Crystal}
			} else if depth >= 3 {
				// iron 40, copper 60
				if roll < 40 {kind = .Iron} else {kind = .Copper}
			} else {
				// depth 1-2: only iron
				kind = .Iron
			}

			game.ore_veins[idx] = Ore_Vein {
				kind = kind,
			}
		}
	}

	logger_debugf(.Gen, "ore veins spawned (depth=%v)", depth)
}

// ─── Anvil spawning (one per floor) ───────────────────────────────────────────
