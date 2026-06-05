package gen

import "core:math/rand"


spawn_hazards :: proc(game: ^Game) {
	depth := game.depth

	// Water: depths 1+, 3-6 tiles (15-25 in flooded cavern)
	if depth >= 1 {
		count: int
		if depth >= 6 && depth <= 7 {
			count = rand.int_max(11) + 15
		} else {
			count = rand.int_max(4) + 3
		}
		placed := 0
		for _ in 0 ..< count * 20 {
			if placed >= count {break}
			x := rand.int_max(MAP_WIDTH - 2) + 1
			y := rand.int_max(MAP_HEIGHT - 2) + 1
			idx := pos_to_idx(x, y)
			if game.tiles[idx].type != .Floor {continue}
			if x == game.player.pos.x && y == game.player.pos.y {continue}
			game.tiles[idx].type = .Water
			placed += 1
		}
	}

	// Gas vents: depths 3+, 2-4 tiles
	if depth >= 3 {
		count := rand.int_max(3) + 2
		placed := 0
		for _ in 0 ..< count * 20 {
			if placed >= count {break}
			x := rand.int_max(MAP_WIDTH - 2) + 1
			y := rand.int_max(MAP_HEIGHT - 2) + 1
			idx := pos_to_idx(x, y)
			if game.tiles[idx].type != .Floor {continue}
			if x == game.player.pos.x && y == game.player.pos.y {continue}
			game.tiles[idx].type = .Gas_Vent
			placed += 1
		}
	}

	// Unstable ground: depths 5+, 2-3 tiles
	if depth >= 5 {
		count := rand.int_max(2) + 2
		placed := 0
		for _ in 0 ..< count * 20 {
			if placed >= count {break}
			x := rand.int_max(MAP_WIDTH - 2) + 1
			y := rand.int_max(MAP_HEIGHT - 2) + 1
			idx := pos_to_idx(x, y)
			if game.tiles[idx].type != .Floor {continue}
			if x == game.player.pos.x && y == game.player.pos.y {continue}
			game.tiles[idx].type = .Unstable
			placed += 1
		}
	}

	// Fire vents: depths 4+, 2-3 tiles
	if depth >= 4 {
		count := rand.int_max(2) + 2
		placed := 0
		for _ in 0 ..< count * 20 {
			if placed >= count {break}
			x := rand.int_max(MAP_WIDTH - 2) + 1
			y := rand.int_max(MAP_HEIGHT - 2) + 1
			idx := pos_to_idx(x, y)
			if game.tiles[idx].type != .Floor {continue}
			if x == game.player.pos.x && y == game.player.pos.y {continue}
			game.tiles[idx].type = .Fire_Vent
			placed += 1
		}
	}

	logger_debugf(.Gen, "hazards spawned (depth=%v)", depth)
}

// ─── Ore vein spawning (depth-gated) ──────────────────────────────────────────
